import SwiftUI

struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var openDay: WorkoutDay?
    @State private var celebration: CelebrationPayload?

    var body: some View {
        VStack(spacing: 0) {
            TopBar()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(1...4, id: \.self) { week in
                            WeekHeader(week: week, progress: store.weekProgress(week))
                                .padding(.top, week == 1 ? 8 : 28)
                                .padding(.bottom, 6)

                            ForEach(0..<7, id: \.self) { d in
                                let day = Plan.day(at: (week - 1) * 7 + d)
                                PathNode(day: day,
                                         state: nodeState(day.index),
                                         offset: waveOffset(day.index)) {
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
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(state == .locked ? Theme.locked : Theme.accentDim.opacity(0.45))
                .frame(width: 4, height: 22)
                .offset(x: offset)

            Button(action: action) {
                ZStack {
                    if state == .current {
                        Circle()
                            .stroke(Theme.accent.opacity(0.35), lineWidth: 4)
                            .frame(width: pulse ? 104 : 76, height: pulse ? 104 : 76)
                            .opacity(pulse ? 0 : 1)
                    }
                    Circle()
                        .fill(fill)
                        .frame(width: 72, height: 72)
                        .shadow(color: glow, radius: state == .current ? 18 : 0)
                    Circle()
                        .fill(Color.black.opacity(0.18))
                        .frame(width: 72, height: 72)
                        .offset(y: 4)
                        .mask(Circle().frame(width: 72, height: 72))
                        .allowsHitTesting(false)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(iconColor)

                    if state == .done {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.gold)
                            .background(Circle().fill(Theme.bg).frame(width: 20, height: 20))
                            .offset(x: 26, y: 24)
                    }
                }
            }
            .buttonStyle(.plain)
            .offset(x: offset)
            .onAppear {
                guard state == .current else { return }
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
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
