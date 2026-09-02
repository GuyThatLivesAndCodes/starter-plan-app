import SwiftUI

struct HistoryView: View {
    @Environment(Store.self) private var store
    @State private var month: Date = Date()
    @State private var selected: DayLog?

    private let cal = Calendar.current

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Text("Your history")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    summaryTile("flame.fill", "\(store.profile.streak)", "Current", Theme.flame)
                    summaryTile("crown.fill", "\(store.profile.bestStreak)", "Best", Theme.gold)
                    summaryTile("bolt.fill", "\(store.profile.xp)", "Total XP", Theme.accent)
                }

                calendar

                if store.logs.isEmpty {
                    Text("No sessions logged yet. Your first one is one tap away.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RECENT")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                        ForEach(store.logs.sorted { $0.completedOn > $1.completedOn }.prefix(10), id: \.dayIndex) { log in
                            Button { Feedback.shared.tap(); selected = log } label: { logRow(log) }
                                .buttonStyle(.plain)
                        }
                    }
                }

                Color.clear.frame(height: 100)
            }
            .padding(20)
        }
        .sheet(item: Binding(get: { selected.map { DayDetail(log: $0) } }, set: { if $0 == nil { selected = nil } })) { detail in
            DayDetailSheet(log: detail.log)
        }
    }

    private struct DayDetail: Identifiable { let log: DayLog; var id: Int { log.dayIndex } }

    private func summaryTile(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(color)
            Text(value).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(Theme.text)
            Text(label.uppercased()).font(.system(size: 10, weight: .heavy, design: .rounded)).foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14).card(Theme.surface)
    }

    private var calendar: some View {
        VStack(spacing: 14) {
            HStack {
                arrow("chevron.left") { shift(-1) }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.text)
                Spacer()
                arrow("chevron.right") { shift(1) }
            }

            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { d in
                    Text(d).font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textDim).frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(gridDays.indices, id: \.self) { i in
                    if let date = gridDays[i] {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
        .padding(18)
        .card(Theme.surface)
    }

    private func dayCell(_ date: Date) -> some View {
        let log = store.log(forDate: date)
        let isToday = cal.isDateInToday(date)
        return Button {
            guard let log else { return }
            Feedback.shared.tap(); selected = log
        } label: {
            Text("\(cal.component(.day, from: date))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(log != nil ? Color(hex: 0x10221A) : (isToday ? Theme.accent : Theme.textDim))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11)
                        .fill(log != nil ? Theme.accent : Theme.surfaceHigh.opacity(0.5))
                )
                .overlay(RoundedRectangle(cornerRadius: 11)
                    .stroke(isToday && log == nil ? Theme.accent : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func arrow(_ name: String, action: @escaping () -> Void) -> some View {
        Button { Feedback.shared.tap(); action() } label: {
            Image(systemName: name).font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textDim).frame(width: 30, height: 30)
                .background(Circle().fill(Theme.surfaceHigh))
        }
        .buttonStyle(.plain)
    }

    private func shift(_ n: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            month = cal.date(byAdding: .month, value: n, to: month) ?? month
        }
    }

    private var gridDays: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let first = interval.start
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let weekday = cal.component(.weekday, from: first)          // 1 = Sunday
        let leading = (weekday + 5) % 7                              // Monday-first
        return Array<Date?>(repeating: nil, count: leading)
            + (0..<count).map { cal.date(byAdding: .day, value: $0, to: first) }
    }

    private func logRow(_ log: DayLog) -> some View {
        let day = Plan.day(at: log.dayIndex)
        return HStack(spacing: 14) {
            Image(systemName: day.kind.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.surfaceHigh))
            VStack(alignment: .leading, spacing: 2) {
                Text(day.kind.title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("Week \(day.week) · \(log.completedOn.formatted(.dateTime.month().day()))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textDim)
            }
            Spacer()
            Text("+\(log.xpEarned) XP")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.gold)
        }
        .padding(12)
        .card(Theme.surface)
    }
}

struct DayDetailSheet: View {
    let log: DayLog

    private func effortColor(_ e: Effort) -> Color {
        switch e {
        case .easy: return Theme.teal
        case .good: return Theme.accent
        case .hard: return Theme.gold
        case .failed: return Theme.danger
        }
    }

    private func miniStat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(Theme.text)
            Text(l).font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surfaceHigh))
    }

    private func detailLine(_ r: SetRecord) -> String {
        var parts = [r.effort.label]
        if r.heldSeconds > 0 { parts.append("held \(r.heldSeconds)s") }
        if r.reps > 0 { parts.append("\(r.reps) reps") }
        if r.restSeconds > 0 {
            parts.append("rested \(r.restSeconds / 60):\(String(format: "%02d", r.restSeconds % 60))")
            if r.restOvertime > 0 { parts.append("+\(r.restOvertime)s over") }
        }
        return parts.joined(separator: " · ")
    }

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let day = Plan.day(at: log.dayIndex)
        let records = store.records(forDay: log.dayIndex)
        let runs = store.cardioSessions(forDay: log.dayIndex)
        let conds = store.conditioningResults(forDay: log.dayIndex)
        let entries = store.entries(forDay: log.dayIndex)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.kind.title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("Week \(day.week) · \(day.weekdayName) · \(log.completedOn.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                }

                ForEach(runs, id: \.persistentModelID) { r in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Trail session", systemImage: "figure.hiking")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.accent)
                            Spacer()
                            Text(r.effort.label)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textDim)
                        }
                        HStack(spacing: 10) {
                            miniStat(RunTracker.clock(r.seconds), "TIME")
                            if r.usedLocation {
                                miniStat(String(format: "%.2f", r.miles), "MILES")
                                miniStat(RunTracker.paceString(r.pace), "/MI")
                            }
                        }
                        if r.usedLocation && !r.splits.isEmpty {
                            let peak = max(r.splits.max() ?? 1, 1)
                            HStack(alignment: .bottom, spacing: 3) {
                                ForEach(Array(r.splits.enumerated()), id: \.offset) { _, m in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(m < peak * 0.6 ? Theme.gold : Theme.accent)
                                        .frame(height: max(3, 34 * m / peak))
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: 36)
                            Text(r.fadePercent > 12 ? "Faded in the back half"
                                 : (r.fadePercent < -8 ? "Finished stronger than you started" : "Pace held steady"))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textDim)
                        }
                        if r.autoPauses > 0 {
                            Text("\(r.autoPauses) auto-pause\(r.autoPauses == 1 ? "" : "s") · \(RunTracker.clock(r.pausedSeconds)) stopped")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textDim.opacity(0.8))
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).card(Theme.surface)
                }

                ForEach(conds, id: \.persistentModelID) { c in
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Conditioning", systemImage: "flame.fill")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.flame)
                        HStack(spacing: 10) {
                            if c.rounds > 0 { miniStat("\(c.rounds)", "ROUNDS") }
                            if c.partialReps > 0 { miniStat("+\(c.partialReps)", "REPS") }
                            if c.seconds > 0 { miniStat(RunTracker.clock(c.seconds), "TIME") }
                        }
                        if !c.roundSplits.isEmpty {
                            Text("Splits: " + c.roundSplits.map { RunTracker.clock($0) }.joined(separator: " · "))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textDim)
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).card(Theme.surface)
                }

                if !records.isEmpty {
                    ForEach(records, id: \.persistentModelID) { r in
                        HStack(spacing: 12) {
                            Image(systemName: r.effort.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(effortColor(r.effort))
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(effortColor(r.effort).opacity(0.15)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Plan.exercise(id: r.exerciseID)?.name ?? r.exerciseID) · set \(r.setNumber)")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.text)
                                Text(detailLine(r))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.textDim)
                            }
                            Spacer()
                            if r.weight > 0 {
                                Text("\(Int(r.weight)) lb")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .card(Theme.surface)
                    }
                } else if entries.isEmpty {
                    Text(day.kind.isRest ? "Rest day banked. Recovery counts." : "No set details recorded.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                } else {
                    ForEach(entries, id: \.exerciseID) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Plan.exercise(id: e.exerciseID)?.name ?? e.exerciseID)
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.text)
                                Text("\(e.setsCompleted) sets completed")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.textDim)
                            }
                            Spacer()
                            if e.weight > 0 {
                                Text("\(Int(e.weight)) lb")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .card(Theme.surface)
                    }
                }

                Text("+\(log.xpEarned) XP earned")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.gold)

                Button("Close") { Feedback.shared.tap(); dismiss() }
                    .buttonStyle(ChunkyButtonStyle())
            }
            .padding(24)
        }
        .background(Theme.bg)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bg)
    }
}
