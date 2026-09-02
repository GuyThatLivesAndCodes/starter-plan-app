import SwiftUI

/// The questionnaire that builds the plan. Six short steps, one decision each.
struct PlanSetupView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let isOnboarding: Bool

    @State private var step = 0
    @State private var prefs = TrainingPreferences()

    private let stepCount = 6

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $step) {
                goalStep.tag(0)
                daysStep.tag(1)
                lengthStep.tag(2)
                equipmentStep.tag(3)
                focusStep.tag(4)
                avoidStep.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            footer
        }
        .background(Theme.bg)
        .onAppear { prefs = store.profile.preferences }
    }

    // MARK: Chrome

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                if step > 0 {
                    Button { Feedback.shared.tap(); withAnimation { step -= 1 } } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textDim)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.surface))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if !isOnboarding {
                    Button { Feedback.shared.tap(); dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textDim)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.surface))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 5) {
                ForEach(0..<stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Theme.accent : Theme.locked)
                        .frame(height: 6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button(step == stepCount - 1 ? "Build my plan" : "Next") {
                Feedback.shared.tap()
                if step == stepCount - 1 {
                    Feedback.shared.celebrate()
                    store.buildPlan(prefs)
                    Notifications.shared.refresh(store: store)
                    dismiss()
                } else {
                    withAnimation { step += 1 }
                }
            }
            .buttonStyle(ChunkyButtonStyle())

            if step == stepCount - 1 {
                Text("You can rebuild this any time from Settings — finished days are kept.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textDim)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .padding(.top, 8)
    }

    private func page<C: View>(_ title: String, _ subtitle: String, @ViewBuilder content: () -> C) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content()
                Color.clear.frame(height: 20)
            }
            .padding(20)
        }
    }

    // MARK: Steps

    private var goalStep: some View {
        page("What are you after?", "This sets how heavy, how many reps, and how much conditioning you get.") {
            VStack(spacing: 10) {
                ForEach(TrainingGoal.allCases) { g in
                    choiceRow(title: g.label, subtitle: g.blurb, selected: prefs.goal == g) {
                        prefs.goal = g
                    }
                }
            }
        }
    }

    private var daysStep: some View {
        page("How many days a week?", "Be honest rather than optimistic. Three days you actually do beats six you don't.") {
            VStack(spacing: 10) {
                ForEach(2...6, id: \.self) { n in
                    choiceRow(title: "\(n) days", subtitle: splitName(n), selected: prefs.daysPerWeek == n) {
                        prefs.daysPerWeek = n
                    }
                }
            }
        }
    }

    private func splitName(_ n: Int) -> String {
        switch n {
        case 2: return "Two full-body sessions"
        case 3: return "Three full-body sessions"
        case 4: return "Upper / lower, twice each"
        case 5: return "Upper, lower, push, pull and a finisher"
        default: return "Push, pull, legs — twice through"
        }
    }

    private var lengthStep: some View {
        page("How long have you got?", "Per session. This decides how many movements land in each one.") {
            VStack(spacing: 10) {
                ForEach([20, 30, 45, 60], id: \.self) { m in
                    choiceRow(title: "\(m) minutes",
                              subtitle: "\(slotsFor(m)) movements per session",
                              selected: prefs.sessionMinutes == m) {
                        prefs.sessionMinutes = m
                    }
                }
            }
        }
    }

    private func slotsFor(_ m: Int) -> Int {
        var p = prefs; p.sessionMinutes = m; return p.slotCount
    }

    private var equipmentStep: some View {
        page("What have you got?", "Pick everything you can get to. Anything you leave out never shows up in your plan.") {
            VStack(spacing: 10) {
                ForEach(Equipment.allCases) { e in
                    let on = e == .bodyweight || prefs.equipment.contains(e)
                    Button {
                        Feedback.shared.tap()
                        guard e != .bodyweight else { return }
                        if prefs.equipment.contains(e) { prefs.equipment.remove(e) } else { prefs.equipment.insert(e) }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: e.icon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(on ? Theme.accent : Theme.textDim)
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 11).fill(on ? Theme.accent.opacity(0.15) : Theme.surfaceHigh))
                            Text(e.label)
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? Theme.accent : Theme.locked)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16).fill(on ? Theme.accent.opacity(0.08) : Theme.surface))
                        .opacity(e == .bodyweight ? 0.7 : 1)
                    }
                    .buttonStyle(.plain)
                }
                Text("Bodyweight is always on — there's always something you can do.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textDim.opacity(0.8))
            }
        }
    }

    private var focusStep: some View {
        page("Anything you want to prioritise?", "Tap the muscles you care about most. Optional — leave it blank for a balanced plan.") {
            VStack(spacing: 14) {
                BodyMap(selectable: true, selected: prefs.focus) { m in
                    if prefs.focus.contains(m) { prefs.focus.remove(m) } else { prefs.focus.insert(m) }
                }
                .frame(height: 260)

                if prefs.focus.isEmpty {
                    Text("Nothing selected — you'll get an even spread.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                } else {
                    FlowChips(items: prefs.focus.map(\.plainLabel).sorted())
                }

                HStack(spacing: 8) {
                    ForEach(Muscle.Region.allCases) { region in
                        Button {
                            Feedback.shared.tap()
                            let all = Muscle.allCases.filter { $0.region == region }
                            if all.allSatisfy(prefs.focus.contains) {
                                all.forEach { prefs.focus.remove($0) }
                            } else {
                                all.forEach { prefs.focus.insert($0) }
                            }
                        } label: {
                            Text(region.label)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.textDim)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Theme.surfaceHigh))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var avoidStep: some View {
        page("Anything to work around?", "Movements that load these get left out entirely. Nothing here is a problem — most people pick none.") {
            VStack(spacing: 10) {
                ForEach(JointStress.allCases) { j in
                    choiceRow(title: j.label,
                              subtitle: "Skip movements that load the \(j.label.lowercased())",
                              selected: prefs.avoid.contains(j)) {
                        if prefs.avoid.contains(j) { prefs.avoid.remove(j) } else { prefs.avoid.insert(j) }
                    }
                }
                Text("Not medical advice. If something hurts in a sharp or joint-deep way, get it looked at.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textDim.opacity(0.75))
            }
        }
    }

    private func choiceRow(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { Feedback.shared.tap(); action() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Theme.accent : Theme.locked)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Theme.accent.opacity(0.10) : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Theme.accent.opacity(0.4) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

/// Simple wrapping chip row.
struct FlowChips: View {
    let items: [String]

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 90), spacing: 6)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { t in
                Text(t)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0x10221A))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accent))
            }
        }
    }
}
