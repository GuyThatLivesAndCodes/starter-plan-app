import SwiftUI

struct CelebrationPayload: Identifiable {
    let id = UUID()
    let xp: Int
    let streak: Int
    let dayTitle: String
    let setsDone: Int
    let bumps: [String]        // exercise names earning a weight bump
}

struct WorkoutView: View {
    let day: WorkoutDay
    let onFinish: (CelebrationPayload) -> Void

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var checks: [String: Set<Int>] = [:]       // exerciseID -> completed set numbers
    @State private var weights: [String: Double] = [:]
    @State private var infoExercise: Exercise?
    @State private var restRemaining: Int?
    @State private var toast: String?
    @State private var bumps: [String: Bool] = [:]

    private var exercises: [Exercise] { day.exercises }
    private var current: Exercise? { exercises.indices.contains(index) ? exercises[index] : nil }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if day.kind.isRest {
                    restDayBody
                } else if let ex = current {
                    ScrollView(showsIndicators: false) {
                        ExerciseCard(exercise: ex,
                                     checked: checks[ex.id] ?? [],
                                     weight: Binding(
                                        get: { weights[ex.id] ?? 0 },
                                        set: { weights[ex.id] = $0 }),
                                     bumpSuggested: bumps[ex.id] ?? false,
                                     onToggle: { toggle(ex, set: $0) },
                                     onInfo: { infoExercise = ex },
                                     onAcceptBump: {
                                        store.acceptBump(for: ex.id, increment: 5)
                                        weights[ex.id] = store.state(for: ex.id).lastWeight
                                        bumps[ex.id] = false
                                        Feedback.shared.tap()
                                        flash("Bumped +5 lb. Earn it.")
                                     })
                            .padding(20)
                            .id(ex.id)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                        Color.clear.frame(height: 100)
                    }
                }

                footer
            }

            if let remaining = restRemaining {
                RestTimerOverlay(remaining: remaining, total: 90) { restRemaining = nil }
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }

            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Capsule().fill(Theme.surfaceHigh))
                        .padding(.bottom, 130)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .sheet(item: $infoExercise) { ExerciseInfoSheet(exercise: $0) }
        .onAppear {
            for ex in exercises {
                let st = store.state(for: ex.id)
                weights[ex.id] = st.lastWeight
                bumps[ex.id] = st.pendingBump
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button { Feedback.shared.tap(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.surface))
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 1) {
                    Text(day.kind.title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("Week \(day.week) · \(day.weekdayName)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                }

                Spacer()
                Color.clear.frame(width: 34, height: 34)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.locked).frame(height: 10)
                    Capsule().fill(Theme.accent)
                        .frame(width: geo.size.width * progress, height: 10)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: progress)
                }
            }
            .frame(height: 10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var restDayBody: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.teal)
            Text("Rest day")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Theme.text)
            Text(day.note ?? "Take it easy.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
            Text("Log it to keep your streak alive — rest counts.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.accent)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if !day.kind.isRest {
                Button {
                    Feedback.shared.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { restRemaining = 90 }
                } label: {
                    Label("Rest 90s", systemImage: "timer")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                }
                .buttonStyle(.plain)
            }

            Button(action: advance) {
                Text(buttonTitle)
            }
            .buttonStyle(ChunkyButtonStyle(color: isLast ? Theme.accent : (currentDone ? Theme.accent : Theme.surfaceHigh),
                                           textColor: (isLast || currentDone) ? Color(hex: 0x10221A) : Theme.textDim))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: Logic

    private var progress: Double {
        guard !day.kind.isRest else { return 1 }
        let done = checks.values.reduce(0) { $0 + $1.count }
        return day.totalSets == 0 ? 1 : Double(done) / Double(day.totalSets)
    }

    private var currentDone: Bool {
        guard let ex = current else { return true }
        return (checks[ex.id]?.count ?? 0) >= ex.sets
    }

    private var isLast: Bool { day.kind.isRest || index >= exercises.count - 1 }

    private var buttonTitle: String {
        if day.kind.isRest { return "Log rest day" }
        if isLast { return "Finish workout" }
        return currentDone ? "Next exercise" : "Skip to next"
    }

    private func toggle(_ ex: Exercise, set: Int) {
        var s = checks[ex.id] ?? []
        if s.contains(set) { s.remove(set) } else {
            s.insert(set)
            Feedback.shared.setChecked()
            if s.count >= ex.sets {
                Feedback.shared.exerciseDone()
                flash(Copy.exerciseDone.randomElement()!)
            } else {
                flash(Copy.setDone.randomElement()!)
            }
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { checks[ex.id] = s }
    }

    private func flash(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.25)) { if toast == text { toast = nil } }
        }
    }

    private func advance() {
        if isLast { finish(); return }
        Feedback.shared.tap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { index += 1 }
    }

    private func finish() {
        var results: [String: (sets: Int, weight: Double)] = [:]
        var bumps: [String] = []
        for ex in exercises {
            let done = checks[ex.id]?.count ?? 0
            let w = weights[ex.id] ?? 0
            results[ex.id] = (sets: done, weight: w)
            let st = store.state(for: ex.id)
            if done >= ex.sets && ex.tracksWeight && st.fullSessionStreak + 1 >= 2 { bumps.append(ex.name) }
        }
        let xp = store.completeDay(day, results: results)
        Feedback.shared.celebrate()
        Notifications.shared.refresh(store: store)
        onFinish(CelebrationPayload(xp: xp,
                                    streak: store.profile.streak,
                                    dayTitle: day.kind.title,
                                    setsDone: checks.values.reduce(0) { $0 + $1.count },
                                    bumps: bumps))
    }
}
