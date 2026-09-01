import SwiftUI

struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var openDay: WorkoutDay?
    @State private var celebration: CelebrationPayload?
    @State private var showOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        CoachSummaryCard()
                            .padding(.top, 12)

                        ForEach(1...4, id: \.self) { week in
                            WeekHeader(week: week, progress: store.weekProgress(week))
                                .padding(.top, week == 1 ? 8 : 28)
                                .padding(.bottom, 6)

                            ForEach(0..<7, id: \.self) { d in
                                let day = Plan.day(at: (week - 1) * 7 + d)
                                PathNode(day: day,
                                         state: nodeState(day.index),
                                         offset: waveOffset(day.index),
                                         previousOffset: d == 0 ? nil : waveOffset(day.index - 1)) {
                                    tap(day)
                                }
                                .id(day.index)
                            }
                        }

                        if store.isPlanFinished { FinishedBanner().padding(.top, 28) }
                        Color.clear.frame(height: 110)
                    }
                    .padding(.horizontal, 20)
                }
                .onAppear {
                    withAnimation { proxy.scrollTo(max(store.currentDayIndex - 1, 0), anchor: .center) }
                }
            }
        }
        .fullScreenCover(item: $openDay) { day in
            WorkoutView(day: day) { payload in
                openDay = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { celebration = payload }
            }
        }
        .fullScreenCover(item: $celebration) { payload in
            CelebrationView(payload: payload) { celebration = nil }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            BodyProfileForm(isOnboarding: true)
        }
        .onAppear {
            if !store.profile.onboarded { showOnboarding = true }
        }
    }

    private func tap(_ day: WorkoutDay) {
        guard store.isUnlocked(day.index) else { Feedback.shared.denied(); return }
        Feedback.shared.tap()
        openDay = day
    }

    private func nodeState(_ index: Int) -> NodeState {
        if store.isComplete(index) { return .done }
        if index == store.currentDayIndex { return .current }
        return store.isUnlocked(index) ? .available : .locked
    }

    /// Winding left-right path like a skill tree.
    private func waveOffset(_ index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0, 62, 88, 62, 0, -62, -88]
        return pattern[index % pattern.count]
    }
}

// MARK: - Top bar

struct TopBar: View {
    @Environment(Store.self) private var store
    @State private var flamePulse = false

    var body: some View {
        HStack(spacing: 14) {
            stat(icon: "flame.fill", value: "\(store.profile.streak)", color: Theme.flame)
                .scaleEffect(flamePulse ? 1.06 : 1)
                .onAppear {
                    guard store.profile.streak > 0 else { return }
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { flamePulse = true }
                }

            stat(icon: "bolt.fill", value: "\(store.profile.xp)", color: Theme.gold)

            stat(icon: "circlebadge.2.fill", value: "\(store.profile.coins)", color: Theme.teal)

            Spacer()

            ZStack {
                Circle().stroke(Theme.locked, lineWidth: 6).frame(width: 42, height: 42)
                Circle()
                    .trim(from: 0, to: store.weekProgress(store.currentWeek))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 42, height: 42)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.weekProgress(store.currentWeek))
                Text("W\(store.currentWeek)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.text)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.bg)
        .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .bottom)
    }

    private func stat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
        }
    }
}

// MARK: - Week header

struct WeekHeader: View {
    let week: Int
    let progress: Double

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("WEEK \(week)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textDim)
            }
            Spacer()
            Text("\(Int(progress * 7))/7")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .card(Theme.surface)
    }

    private var subtitle: String {
        ["Find your footing", "Add a little weight", "Turn up the volume", "Finish strong"][week - 1]
    }
}

// MARK: - Path node

enum NodeState { case done, current, available, locked }

struct PathNode: View {
    let day: WorkoutDay
    let state: NodeState
    let offset: CGFloat
    let previousOffset: CGFloat?
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            if let previousOffset {
                PathConnector(fromOffset: previousOffset, toOffset: offset)
                    .stroke(state == .locked ? Theme.locked : Theme.accentDim.opacity(0.55),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(height: 34)
            } else {
                Color.clear.frame(height: 10)
            }

            Button(action: action) {
                Circle()
                    .fill(fill)
                    .frame(width: 72, height: 72)
                    .shadow(color: glow, radius: state == .current ? 18 : 0)
                    .overlay(
                        Circle()
                            .fill(Color.black.opacity(0.16))
                            .mask(Circle().offset(y: 5))
                    )
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(iconColor)
                    )
                    // Pulse and badge live in overlays so they never push the layout around.
                    .overlay(
                        Circle()
                            .stroke(Theme.accent.opacity(0.35), lineWidth: 4)
                            .scaleEffect(pulse ? 1.5 : 1)
                            .opacity(state == .current ? (pulse ? 0 : 0.9) : 0)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if state == .done {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.gold)
                                .background(Circle().fill(Theme.bg).frame(width: 18, height: 18))
                                .offset(x: 6, y: 4)
                        }
                    }
            }
            .buttonStyle(.plain)
            .offset(x: offset)
            .onAppear {
                guard state == .current else { return }
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { pulse = true }
            }

            VStack(spacing: 1) {
                Text(day.weekdayName)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(state == .locked ? Theme.textDim.opacity(0.6) : Theme.text)
                Text(day.kind.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textDim.opacity(state == .locked ? 0.5 : 1))
            }
            .padding(.top, 6)
            .offset(x: offset)
        }
        .frame(maxWidth: .infinity)
    }

    private var icon: String {
        switch state {
        case .done: return "checkmark"
        case .locked: return "lock.fill"
        default: return day.kind.icon
        }
    }

    private var fill: Color {
        switch state {
        case .done: return Theme.accentDim
        case .current: return Theme.accent
        case .available: return Theme.surfaceHigh
        case .locked: return Theme.locked
        }
    }

    private var iconColor: Color {
        switch state {
        case .current: return Color(hex: 0x10221A)
        case .done: return .white
        case .locked: return Theme.textDim.opacity(0.7)
        case .available: return Theme.text
        }
    }

    private var glow: Color { state == .current ? Theme.accent.opacity(0.55) : .clear }
}

/// The line between two nodes — curves from the previous node's x to this one's.
struct PathConnector: Shape {
    let fromOffset: CGFloat
    let toOffset: CGFloat

    func path(in rect: CGRect) -> Path {
        let start = CGPoint(x: rect.midX + fromOffset, y: rect.minY)
        let end = CGPoint(x: rect.midX + toOffset, y: rect.maxY)
        var p = Path()
        p.move(to: start)
        p.addCurve(to: end,
                   control1: CGPoint(x: start.x, y: rect.midY),
                   control2: CGPoint(x: end.x, y: rect.midY))
        return p
    }
}

/// The coach's read on how the user is doing, right at the top of the plan.
struct CoachSummaryCard: View {
    @Environment(Store.self) private var store
    @State private var showProfile = false

    var body: some View {
        Group {
            if let r = Coach.readout(store: store) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().stroke(Theme.locked, lineWidth: 7).frame(width: 58, height: 58)
                            Circle()
                                .trim(from: 0, to: Double(r.score) / 100)
                                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 58, height: 58)
                            Text("\(r.score)")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.text)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.label)
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.text)
                            Text(r.detail)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    ForEach(Coach.warnings(store: store).prefix(2)) { w in
                        WarningRow(warning: w)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(Theme.surface)
            } else {
                Button {
                    Feedback.shared.tap(); showProfile = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 20)).foregroundStyle(Theme.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tell the coach about you")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.text)
                            Text("Age, height and weight — then it can pick your weights for you.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textDim)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textDim)
                    }
                    .padding(16)
                    .card(Theme.surface)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showProfile) { BodyProfileForm(isOnboarding: false) }
            }
        }
    }
}

struct FinishedBanner: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("🏆").font(.system(size: 44))
            Text("4 weeks. Done.")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Theme.text)
            Text("Reset the plan in Settings to run it back heavier.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .card(Theme.surface)
    }
}
