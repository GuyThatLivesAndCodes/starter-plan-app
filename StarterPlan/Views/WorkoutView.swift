import SwiftUI

struct CelebrationPayload: Identifiable {
    let id = UUID()
    let xp: Int
    let coins: Int
    let streak: Int
    let dayTitle: String
    let setsDone: Int
    let notes: [String]        // what the coach learned / will change next time
}

private enum Phase: Equatable {
    case lift          // doing the current set
    case rate          // "how did that feel?"
    case rest          // counting down (and up)
}

struct WorkoutView: View {
    let day: WorkoutDay
    let onFinish: (CelebrationPayload) -> Void

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var exerciseIndex = 0
    @State private var setNumber = 1
    @State private var phase: Phase = .lift
    @State private var weights: [String: Double] = [:]
    @State private var suggestions: [String: Coach.Suggestion] = [:]
    @State private var doneSets: [String: Int] = [:]
    @State private var pendingEffort: Effort = .good
    @State private var coinsEarned = 0
    @State private var infoExercise: Exercise?
    @State private var toast: String?
    @State private var coachNote: String?
    @State private var reps = 0
    @State private var heldSeconds = 0
    @State private var pendingRun: PendingRun?
    @State private var pendingCond: PendingCond?
    @State private var effortsThisExercise: [Effort] = []
    @State private var activityNotes: [String] = []

    struct PendingRun {
        var seconds: Int; var meters: Double; var splits: [Double]
        var autoPauses: Int; var pausedSeconds: Int; var usedLocation: Bool
        var low: Int; var high: Int
    }
    struct PendingCond {
        var rounds: Int; var partial: Int; var seconds: Int; var splits: [Int]
    }

    private var exercises: [Exercise] { day.exercises }
    private var current: Exercise? { exercises.indices.contains(exerciseIndex) ? exercises[exerciseIndex] : nil }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if day.kind.isRest {
                    restDayBody
                    footer
                } else if let ex = current {
                    switch phase {
                    case .lift:
                        activityScreen(for: ex)

                    case .rate:
                        EffortPicker(exercise: ex,
                                     setNumber: setNumber,
                                     wholeActivity: pendingRun != nil || pendingCond != nil) { effort in
                            record(effort: effort, for: ex)
                        }

                    case .rest:
                        RestPhaseView(target: Coach.restTarget(for: ex, profile: store.profile),
                                      nextLabel: nextRestLabel,
                                      store: store) { rested in
                            finishRest(seconds: rested, exercise: ex)
                        }
                    }
                }
            }

            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Capsule().fill(Theme.surfaceHigh))
                        .padding(.bottom, 120)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .sheet(item: $infoExercise) { ExerciseInfoSheet(exercise: $0) }
        .onAppear(perform: prepare)
    }

    // MARK: Per-activity screens

    @ViewBuilder
    private func activityScreen(for ex: Exercise) -> some View {
        switch ex.modality {
        case .reps:
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if let s = suggestions[ex.id] { CoachBanner(suggestion: s) }
                    ExerciseCard(exercise: ex,
                                 currentSet: setNumber,
                                 setsDone: doneSets[ex.id] ?? 0,
                                 weight: Binding(get: { weights[ex.id] ?? 0 },
                                                 set: { weights[ex.id] = $0 }),
                                 perSide: Coach.perSideLifts.contains(ex.id),
                                 onInfo: { infoExercise = ex })
                    if !ex.tracksWeight && ex.repTarget > 0 {
                        RepTallyView(exercise: ex, target: ex.repTarget, reps: $reps)
                    }
                    if let note = coachNote { CoachNote(text: note) }
                    ForEach(Coach.warnings(store: store, exercise: ex).prefix(2)) { w in
                        WarningRow(warning: w)
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(20)
            }
            footer

        case let .hold(low, high):
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HoldTimerView(exercise: ex,
                                  target: Coach.holdTarget(for: ex, store: store),
                                  setNumber: setNumber) { seconds in
                        heldSeconds = seconds
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { phase = .rate }
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Theme.textDim)
                        Text("The clock is just for you — the coach sets your next target from how the hold felt, not from the seconds. Plan range \(low)–\(high)s.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).card(Theme.surface)
                    Button { infoExercise = ex } label: {
                        Label("How to do this", systemImage: "questionmark.circle")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                    Color.clear.frame(height: 20)
                }
                .padding(20)
            }

        case let .trail(low, high):
            let plan = Coach.trailPlan(for: ex, store: store)
            TrailSessionView(exercise: ex,
                             targetLow: plan.lowMin > 0 ? plan.lowMin : low,
                             targetHigh: plan.highMin > 0 ? plan.highMin : high) { tracker in
                pendingRun = PendingRun(seconds: tracker.elapsed, meters: tracker.meters,
                                        splits: tracker.splits, autoPauses: tracker.autoPauses,
                                        pausedSeconds: tracker.pausedSeconds,
                                        usedLocation: tracker.usedLocation,
                                        low: plan.lowMin, high: plan.highMin)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { phase = .rate }
            }

        case let .amrap(minutes, movements):
            AmrapView(exercise: ex, minutes: minutes, movements: movements,
                      bestRounds: store.state(for: ex.id).bestRounds,
                      brief: Coach.conditioningBrief(for: ex, store: store)) { rounds, partial, seconds, splits in
                pendingCond = PendingCond(rounds: rounds, partial: partial, seconds: seconds, splits: splits)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { phase = .rate }
            }

        case let .rounds(count, movements, rest):
            RoundsRunnerView(exercise: ex, roundCount: count, movements: movements, restSeconds: rest,
                             brief: Coach.conditioningBrief(for: ex, store: store)) { rounds, seconds, splits in
                pendingCond = PendingCond(rounds: rounds, partial: 0, seconds: seconds, splits: splits)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { phase = .rate }
            }

        case let .forTime(rounds, movements):
            let best = store.conditioningResults(exerciseID: ex.id).map(\.seconds).filter { $0 > 0 }.min() ?? 0
            ForTimeView(exercise: ex, roundCount: rounds, movements: movements, previousBest: best,
                        brief: Coach.conditioningBrief(for: ex, store: store)) { done, seconds, splits in
                pendingCond = PendingCond(rounds: done, partial: 0, seconds: seconds, splits: splits)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { phase = .rate }
            }
        }
    }

    // MARK: Setup

    private func prepare() {
        for ex in exercises {
            guard case .reps = ex.modality else { continue }
            let s = Coach.suggestion(for: ex, store: store)
            suggestions[ex.id] = s
            weights[ex.id] = s.weight
        }
        if let first = current { reps = first.repTarget }
    }

    // MARK: Header / footer

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
                    Text(phaseCaption)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                }
                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "circlebadge.2.fill").font(.system(size: 11))
                    Text("\(coinsEarned)").font(.system(size: 13, weight: .black, design: .rounded))
                }
                .foregroundStyle(Theme.gold)
                .frame(width: 46)
                .contentTransition(.numericText())
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

    private var phaseCaption: String {
        guard let ex = current, !day.kind.isRest else { return "Week \(day.week) · \(day.weekdayName)" }
        switch phase {
        case .lift:
            if ex.modality.isSingleEffort { return "Week \(day.week) · \(day.weekdayName)" }
            return "\(ex.name) · set \(setNumber) of \(ex.sets)"
        case .rate: return "How did that feel?"
        case .rest: return "Resting"
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: primaryAction) { Text(buttonTitle) }
                .buttonStyle(ChunkyButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var buttonTitle: String {
        if day.kind.isRest { return "Log rest day" }
        guard let ex = current else { return "Finish workout" }
        if !ex.tracksWeight && ex.repTarget > 0 { return "Set \(setNumber) done · \(reps) reps" }
        return "Set \(setNumber) done · \(weightLabel(ex))"
    }

    private func weightLabel(_ ex: Exercise) -> String {
        let w = weights[ex.id] ?? 0
        guard ex.tracksWeight, w > 0 else { return "bodyweight" }
        return "\(Int(w)) lb"
    }

    private var progress: Double {
        guard !day.kind.isRest else { return 1 }
        let done = doneSets.values.reduce(0, +)
        return day.totalSets == 0 ? 1 : Double(done) / Double(day.totalSets)
    }

    private var nextRestLabel: String {
        guard let ex = current else { return "Continue" }
        if setNumber <= ex.sets { return "Start set \(setNumber)" }
        return exerciseIndex + 1 < exercises.count ? "Next exercise" : "Finish workout"
    }

    // MARK: Flow

    private func primaryAction() {
        if day.kind.isRest { finish(); return }
        Feedback.shared.setChecked()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { phase = .rate }
    }

    private func record(effort: Effort, for ex: Exercise) {
        // Trail and conditioning are one effort for the whole activity.
        if let run = pendingRun {
            let session = CardioSession(dayIndex: day.index, exerciseID: ex.id,
                                        seconds: run.seconds, meters: run.meters,
                                        targetLowMin: run.low, targetHighMin: run.high,
                                        usedLocation: run.usedLocation, autoPauses: run.autoPauses,
                                        pausedSeconds: run.pausedSeconds, splits: run.splits, effort: effort)
            store.save(session)
            activityNotes.append(Coach.apply(session, exercise: ex, store: store))
            doneSets[ex.id] = ex.sets
            store.awardCoins(for: effort, restOvertime: 0)
            pendingRun = nil
            finish()
            return
        }
        if let cond = pendingCond {
            let result = ConditioningResult(dayIndex: day.index, exerciseID: ex.id,
                                            rounds: cond.rounds, partialReps: cond.partial,
                                            seconds: cond.seconds, roundSplits: cond.splits, effort: effort)
            store.save(result)
            if let n = Coach.apply(result, exercise: ex, store: store) { activityNotes.append(n) }
            doneSets[ex.id] = ex.sets
            store.awardCoins(for: effort, restOvertime: 0)
            pendingCond = nil
            finish()
            return
        }

        let weight = weights[ex.id] ?? 0
        let target = Coach.restTarget(for: ex, profile: store.profile)
        pendingEffort = effort
        doneSets[ex.id] = (doneSets[ex.id] ?? 0) + 1

        let rec = SetRecord(dayIndex: day.index, exerciseID: ex.id, setNumber: setNumber,
                            weight: weight, effort: effort, restSeconds: 0, restTarget: target)
        rec.heldSeconds = heldSeconds
        rec.reps = ex.tracksWeight ? 0 : reps
        store.save(rec)
        effortsThisExercise.append(effort)
        heldSeconds = 0

        // Mid-workout weight correction from the coach.
        if let nudge = Coach.nudgeAfterSet(exercise: ex, effort: effort, weight: weight, setNumber: setNumber) {
            if nudge.adjust != 0 { weights[ex.id] = max(0, weight + nudge.adjust) }
            coachNote = nudge.message
        } else {
            coachNote = nil
        }

        setNumber += 1
        let lastSetOfLastExercise = setNumber > ex.sets && exerciseIndex + 1 >= exercises.count

        if lastSetOfLastExercise {
            finish()
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { phase = .rest }
        }
    }

    private func finishRest(seconds: Int, exercise ex: Exercise) {
        // Attach the real rest length to the set that was just logged.
        if let rec = store.records(exerciseID: ex.id).first(where: { $0.dayIndex == day.index && $0.setNumber == setNumber - 1 }) {
            rec.restSeconds = seconds
            let coins = store.awardCoins(for: pendingEffort, restOvertime: rec.restOvertime)
            withAnimation { coinsEarned += coins }
        }
        try? store.context.save()

        if setNumber > ex.sets {
            if case .hold = ex.modality,
               let n = Coach.applyHold(exercise: ex, efforts: effortsThisExercise, store: store) {
                activityNotes.append(n)
            }
            effortsThisExercise = []
            exerciseIndex += 1
            setNumber = 1
            coachNote = nil
            reps = current?.repTarget ?? 0
            flash(Copy.exerciseDone.randomElement()!)
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { phase = .lift }
    }

    private func flash(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.25)) { if toast == text { toast = nil } }
        }
    }

    private func finish() {
        if let ex = current, case .hold = ex.modality,
           let n = Coach.applyHold(exercise: ex, efforts: effortsThisExercise, store: store) {
            activityNotes.append(n)
        }
        var results: [String: (sets: Int, weight: Double)] = [:]
        for ex in exercises {
            results[ex.id] = (sets: doneSets[ex.id] ?? 0, weight: weights[ex.id] ?? 0)
        }
        let xp = store.completeDay(day, results: results)

        // Bonus coins for finishing the whole session.
        let bonus = day.kind.isRest ? 5 : 15
        store.awardBonus(bonus)

        // What the coach will do differently next time.
        var notes: [String] = activityNotes.filter { !$0.isEmpty }
        for ex in exercises where ex.tracksWeight {
            let next = Coach.suggestion(for: ex, store: store)
            if next.direction == .up { notes.append("\(ex.name) → \(Int(next.weight)) lb next time") }
            if next.direction == .down { notes.append("\(ex.name) → easing to \(Int(next.weight)) lb") }
        }

        Feedback.shared.celebrate()
        Notifications.shared.refresh(store: store)
        onFinish(CelebrationPayload(xp: xp,
                                    coins: coinsEarned + bonus,
                                    streak: store.profile.streak,
                                    dayTitle: day.kind.title,
                                    setsDone: doneSets.values.reduce(0, +),
                                    notes: notes))
    }

    // MARK: Rest day

    private var restDayBody: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "moon.zzz.fill").font(.system(size: 64)).foregroundStyle(Theme.teal)
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
}

// MARK: - Coach UI bits

struct CoachBanner: View {
    let suggestion: Coach.Suggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(tint)
                Text(suggestion.headline)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(confidenceLabel)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textDim)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.surfaceHigh))
            }
            Text(suggestion.reason)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.corner).fill(tint.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner).stroke(tint.opacity(0.3), lineWidth: 1))
    }

    private var tint: Color {
        switch suggestion.direction {
        case .up: return Theme.accent
        case .down: return Theme.flame
        case .hold: return Theme.teal
        case .start: return Theme.gold
        }
    }

    private var icon: String {
        switch suggestion.direction {
        case .up: return "arrow.up.circle.fill"
        case .down: return "arrow.down.circle.fill"
        case .hold: return "equal.circle.fill"
        case .start: return "sparkles"
        }
    }

    private var confidenceLabel: String {
        switch suggestion.confidence {
        case .estimate: return "ESTIMATE"
        case .tracking: return "LEARNING"
        case .dialedIn: return "DIALED IN"
        }
    }
}

struct CoachNote: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "quote.bubble.fill").foregroundStyle(Theme.teal)
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(Theme.surfaceHigh)
    }
}

struct WarningRow: View {
    let warning: Coach.Warning
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: warning.severity == .caution ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(warning.severity == .caution ? Theme.gold : Theme.textDim)
            Text(warning.text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
    }
}

// MARK: - Effort picker

struct EffortPicker: View {
    let exercise: Exercise
    let setNumber: Int
    var wholeActivity: Bool = false
    let onPick: (Effort) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text(wholeActivity ? "How did that go?" : "Set \(setNumber) — how did that feel?")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Theme.text)
            Text(wholeActivity
                 ? "Your answer plus what the session data shows decides the next target."
                 : "Be honest. This is what the coach uses to pick your next weight.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                ForEach(Effort.allCases) { e in
                    Button {
                        Feedback.shared.tap()
                        onPick(e)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: e.icon)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(color(e))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(color(e).opacity(0.15)))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.label)
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.text)
                                Text(blurb(e))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.textDim)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .card(Theme.surface)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
    }

    private func color(_ e: Effort) -> Color {
        switch e {
        case .easy: return Theme.teal
        case .good: return Theme.accent
        case .hard: return Theme.gold
        case .failed: return Theme.danger
        }
    }

    private func blurb(_ e: Effort) -> String {
        if wholeActivity {
            switch e {
            case .easy: return "Could have kept going comfortably"
            case .good: return "Worked for it, finished strong"
            case .hard: return "Really had to dig in"
            case .failed: return "Bailed out before the end"
            }
        }
        switch e {
        case .easy: return "Could have done several more"
        case .good: return "Finished it, last rep was work"
        case .hard: return "Grinding, form started slipping"
        case .failed: return "Stopped short or racked it early"
        }
    }
}
