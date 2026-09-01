import Foundation

/// The coaching algorithm. Everything the app "decides" for the user lives here:
/// what weight to start at, how to adjust it from how the last sets actually felt,
/// how long to rest, and when to flag something worth being careful about.
enum Coach {

    // MARK: - Types

    struct Suggestion {
        var weight: Double            // 0 == bodyweight / no load
        var perSide: Bool
        var headline: String
        var reason: String
        var direction: Direction
        var confidence: Confidence
    }

    enum Direction { case up, hold, down, start }
    enum Confidence { case estimate, tracking, dialedIn }

    struct Warning: Identifiable {
        let id = UUID()
        let text: String
        let severity: Severity
        enum Severity { case info, caution }
    }

    // MARK: - Static references

    /// Working-set load as a fraction of bodyweight for a novice lifter.
    /// Deliberately conservative — the algorithm walks it up from real feedback.
    private static let bodyweightRatio: [String: Double] = [
        "back_squat": 0.55,
        "bench_press": 0.45,
        "db_shoulder_press": 0.15,   // per hand
        "rdl": 0.60,
        "db_rows": 0.18              // per hand
    ]

    static let perSideLifts: Set<String> = ["db_shoulder_press", "db_rows"]

    /// Rest the app asks for between sets, in seconds.
    static func restTarget(for exercise: Exercise, profile: Profile) -> Int {
        let base: Int
        switch exercise.id {
        case "back_squat", "rdl", "bench_press": base = 120
        case "db_shoulder_press", "db_rows", "walking_lunges", "pullups": base = 90
        default: base = 60
        }
        var seconds = base
        if profile.experience == .beginner { seconds += 15 }
        if profile.age >= 50 { seconds += 15 }
        return seconds
    }

    // MARK: - Baseline from body stats

    /// First-session estimate, before there is any performance history.
    static func baseline(for exercise: Exercise, profile: Profile) -> Double {
        guard exercise.tracksWeight,
              let ratio = bodyweightRatio[exercise.id],
              profile.hasBody else { return 0 }

        var w = profile.bodyWeightLb * ratio
        w *= sexFactor(profile.sex)
        w *= experienceFactor(profile.experience)
        w *= ageFactor(profile.age)

        // Very high BMI usually means bodyweight overstates trained strength.
        if profile.bmi > 32 { w *= 0.85 }

        let bar = perSideLifts.contains(exercise.id) ? 5.0 : 45.0   // empty bar floor
        return max(bar, round5(w))
    }

    private static func sexFactor(_ s: BodySex) -> Double {
        switch s {
        case .male: return 1.0
        case .female: return 0.72
        case .unspecified: return 0.86
        }
    }

    private static func experienceFactor(_ e: Experience) -> Double {
        switch e {
        case .beginner: return 1.0
        case .some: return 1.25
        case .experienced: return 1.5
        }
    }

    private static func ageFactor(_ age: Int) -> Double {
        guard age > 0 else { return 0.9 }
        if age < 18 { return 0.75 }
        if age <= 30 { return 1.0 }
        return max(0.7, 1.0 - Double(age - 30) * 0.007)
    }

    private static func round5(_ v: Double) -> Double { (v / 5).rounded() * 5 }

    // MARK: - The adaptive suggestion

    /// Reads the last session's real sets and decides what to load today.
    static func suggestion(for exercise: Exercise, store: Store) -> Suggestion {
        let profile = store.profile
        let perSide = perSideLifts.contains(exercise.id)

        guard exercise.tracksWeight else {
            return Suggestion(weight: 0, perSide: false,
                              headline: "Bodyweight",
                              reason: bodyweightReason(exercise, profile: profile),
                              direction: .hold, confidence: .tracking)
        }

        let history = store.records(exerciseID: exercise.id)
        guard let lastDay = history.first?.dayIndex else {
            let w = baseline(for: exercise, profile: profile)
            return Suggestion(
                weight: w, perSide: perSide,
                headline: profile.hasBody ? "Start here" : "Pick a starting weight",
                reason: profile.hasBody
                    ? "Estimated from your height, weight, age and experience. Treat set 1 as a test — if it flies up, add weight before set 2."
                    : "Add your details in Settings and the coach can estimate this for you.",
                direction: .start, confidence: .estimate)
        }

        let last = history.filter { $0.dayIndex == lastDay }
        let lastWeight = last.map(\.weight).max() ?? baseline(for: exercise, profile: profile)
        let completed = last.filter { $0.effort != .failed }.count
        let hitAllSets = completed >= exercise.sets
        let avgEffort = Double(last.map(\.effort.rawValue).reduce(0, +)) / Double(max(last.count, 1))
        let avgOvertime = last.map(\.restOvertime).reduce(0, +) / max(last.count, 1)
        let failed = last.contains { $0.effort == .failed }

        // Two full clean sessions in a row is the classic progression trigger.
        let priorDays = Array(Set(history.map(\.dayIndex))).sorted(by: >)
        var cleanStreak = 0
        for d in priorDays {
            let sets = history.filter { $0.dayIndex == d }
            let clean = sets.count >= exercise.sets && !sets.contains { $0.effort == .failed }
                && Double(sets.map(\.effort.rawValue).reduce(0, +)) / Double(sets.count) <= 1.4
            if clean { cleanStreak += 1 } else { break }
        }

        let confidence: Confidence = priorDays.count >= 3 ? .dialedIn : .tracking
        let step = increment(for: exercise)

        // Down first — safety beats progress.
        if failed {
            return Suggestion(weight: max(minimum(exercise), lastWeight - step * 2), perSide: perSide,
                              headline: "Back off a little",
                              reason: "You couldn't finish a set last time at \(fmt(lastWeight)). Dropping \(fmt(step * 2)) so every rep is clean — that's how you actually get stronger.",
                              direction: .down, confidence: confidence)
        }
        if avgEffort >= 2.4 || !hitAllSets {
            return Suggestion(weight: max(minimum(exercise), lastWeight - step), perSide: perSide,
                              headline: "Ease off one notch",
                              reason: !hitAllSets
                                ? "You stopped short of \(exercise.sets) sets last time. Slightly lighter today so you finish all of them."
                                : "Last session graded out hard across the board. A small drop today, then we build back up.",
                              direction: .down, confidence: confidence)
        }
        if avgOvertime > 75 {
            return Suggestion(weight: lastWeight, perSide: perSide,
                              headline: "Hold at \(fmt(lastWeight))",
                              reason: "You needed about \(avgOvertime)s of extra rest between sets last time. Same weight today — when the rest shortens, the weight goes up.",
                              direction: .hold, confidence: confidence)
        }
        if avgEffort <= 0.5 && hitAllSets {
            let jump = step * 2
            return Suggestion(weight: lastWeight + jump, perSide: perSide,
                              headline: "Time to add weight",
                              reason: "Every set felt easy at \(fmt(lastWeight)). Adding \(fmt(jump)) — it should feel like real work by set 3.",
                              direction: .up, confidence: confidence)
        }
        if cleanStreak >= 2 && hitAllSets {
            return Suggestion(weight: lastWeight + step, perSide: perSide,
                              headline: "Level up",
                              reason: "Two clean sessions in a row at \(fmt(lastWeight)). Adding \(fmt(step)) — the classic way to keep making progress.",
                              direction: .up, confidence: confidence)
        }
        return Suggestion(weight: lastWeight, perSide: perSide,
                          headline: "Stay at \(fmt(lastWeight))",
                          reason: "Last session was solid but not easy. One more clean session here and the coach will add weight.",
                          direction: .hold, confidence: confidence)
    }

    /// Mid-workout reaction to the set that just happened.
    static func nudgeAfterSet(exercise: Exercise, effort: Effort, weight: Double, setNumber: Int) -> (message: String, adjust: Double)? {
        guard exercise.tracksWeight, weight > 0 else {
            switch effort {
            case .easy: return ("Too easy — slow the reps down and squeeze at the top.", 0)
            case .failed: return ("No shame in cutting reps. Finish the set with what you've got.", 0)
            default: return nil
            }
        }
        let step = increment(for: exercise)
        switch effort {
        case .easy where setNumber == 1:
            return ("That was a warm-up. Bumping \(fmt(step * 2)) for the next set.", step * 2)
        case .easy:
            return ("Still easy — \(fmt(step)) more on the next set.", step)
        case .failed:
            return ("Dropping \(fmt(step * 2)) so the next set is one you can finish.", -step * 2)
        case .hard where setNumber >= 2:
            return ("Getting heavy. Taking \(fmt(step)) off to keep your form honest.", -step)
        default:
            return nil
        }
    }

    private static func increment(for exercise: Exercise) -> Double {
        switch exercise.id {
        case "back_squat", "rdl": return 10
        case "bench_press": return 5
        default: return 5
        }
    }

    private static func minimum(_ exercise: Exercise) -> Double {
        perSideLifts.contains(exercise.id) ? 5 : 45
    }

    private static func fmt(_ w: Double) -> String { "\(Int(w)) lb" }

    private static func bodyweightReason(_ exercise: Exercise, profile: Profile) -> String {
        switch exercise.id {
        case "pullups":
            return "Use whatever band or box gets you 5 controlled reps. When 5 feels easy, switch to a lighter band."
        case "plank", "hollow_hold":
            return "Hold until your form breaks, not until the clock runs out. Quality over seconds."
        default:
            return "No weight needed — control the tempo and the movement does the work."
        }
    }

    // MARK: - Performance read

    struct Readout {
        let score: Int              // 0-100
        let label: String
        let detail: String
        let ratio: Double           // actual load vs. profile baseline
    }

    /// How the user is doing relative to what their body stats predict, blended
    /// with how consistently they're finishing sets.
    static func readout(store: Store) -> Readout? {
        let profile = store.profile
        let records = store.allRecords()
        guard profile.hasBody else { return nil }
        guard !records.isEmpty else {
            return Readout(score: 0, label: "Ready to start",
                           detail: "Log your first session and the coach starts learning what you can handle.",
                           ratio: 0)
        }

        let lifts = (Plan.strengthA + Plan.strengthB).filter(\.tracksWeight)
        var ratios: [Double] = []
        for lift in lifts {
            let base = baseline(for: lift, profile: profile)
            guard base > 0 else { continue }
            let best = records.filter { $0.exerciseID == lift.id && $0.effort != .failed }.map(\.weight).max() ?? 0
            guard best > 0 else { continue }
            ratios.append(best / base)
        }
        let loadRatio = ratios.isEmpty ? 0 : ratios.reduce(0, +) / Double(ratios.count)

        let finished = records.filter { $0.effort != .failed }.count
        let consistency = Double(finished) / Double(max(records.count, 1))
        let planProgress = Double(store.completed.count) / Double(Plan.days.count)

        let raw = min(1.4, loadRatio) / 1.4 * 55 + consistency * 25 + planProgress * 20
        let score = max(0, min(100, Int(raw.rounded())))

        let label: String
        let detail: String
        switch loadRatio {
        case 0..<0.75:
            label = "Building the base"
            detail = "You're lifting below the estimate for your size — completely normal early on. Trust the small jumps."
        case 0.75..<1.05:
            label = "Right on track"
            detail = "Your loads line up with what someone your size and experience should be handling. Keep the sessions clean."
        case 1.05..<1.35:
            label = "Ahead of the curve"
            detail = "You're moving more than your profile predicts. Progress will slow down soon — that's fine, not failure."
        default:
            label = "Well past the estimate"
            detail = "Strong numbers for your profile. Prioritise form and recovery over adding more weight."
        }
        return Readout(score: score, label: label, detail: detail, ratio: loadRatio)
    }

    // MARK: - Warnings ("as needed", never nagging)

    static func warnings(store: Store, exercise: Exercise? = nil) -> [Warning] {
        let p = store.profile
        var out: [Warning] = []
        guard p.hasBody else { return out }

        if p.age >= 55 {
            out.append(Warning(text: "Give yourself a longer warm-up than the app asks for — 5–10 easy minutes before the first set.", severity: .info))
        }
        if p.age < 18 {
            out.append(Warning(text: "Still growing: keep the weights light enough that every rep looks the same, and get an adult to check your form.", severity: .caution))
        }
        if p.bmi >= 30 {
            out.append(Warning(text: "Swap running for a brisk walk or bike if your knees or ankles complain — the cardio still counts.", severity: .info))
        }
        if p.bmi > 0 && p.bmi < 18.5 {
            out.append(Warning(text: "You're on the light side for your height. Eat enough to fuel this — strength won't come from training alone.", severity: .info))
        }
        if p.experience == .beginner {
            out.append(Warning(text: "First few weeks should feel too easy. Soreness is fine; sharp or joint pain means stop that exercise for the day.", severity: .caution))
        }
        if let ex = exercise, ex.id == "back_squat" || ex.id == "rdl" {
            out.append(Warning(text: "If your lower back rounds or your form falls apart, end the set there. Nothing good happens after that rep.", severity: .caution))
        }
        if store.profile.streak >= 6 {
            out.append(Warning(text: "\(store.profile.streak) days straight. Recovery is part of the program — take the rest days as written.", severity: .info))
        }
        return out
    }
}
