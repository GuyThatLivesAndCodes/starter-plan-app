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
        "goblet_squat": 0.25,
        "kb_front_squat": 0.22,
        "bench_press": 0.45,
        "db_bench": 0.18,            // per hand
        "rdl": 0.60,
        "db_rdl": 0.22,              // per hand
        "kb_swing": 0.20,
        "db_shoulder_press": 0.15,   // per hand
        "lateral_raise": 0.05,       // per hand
        "db_rows": 0.18,             // per hand
        "db_curl": 0.09,             // per hand
        "step_up": 0.15,             // per hand
        "walking_lunges": 0.15,      // per hand
        "split_squat": 0.15,         // per hand
        "farmer_carry": 0.30         // per hand
    ]

    static let perSideLifts: Set<String> = [
        "db_shoulder_press", "db_rows", "db_bench", "db_rdl", "db_curl",
        "lateral_raise", "step_up", "walking_lunges", "split_squat", "farmer_carry"
    ]

    /// Rest the app asks for between sets, in seconds.
    static func restTarget(for exercise: Exercise, profile: Profile) -> Int {
        // The goal sets the baseline; big compound lifts earn a little more.
        var base = profile.preferences.goal.restSeconds
        switch exercise.pattern {
        case .squat, .hinge: base += 20
        case .core, .mobility, .carry: base -= 20
        default: break
        }
        if exercise.difficulty >= 3 { base += 15 }
        var seconds = max(30, base)
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

    // MARK: - Trail sessions

    struct TrailPlan {
        var lowMin: Int
        var highMin: Int
        var headline: String
        var reason: String
    }

    static func trailPlan(for exercise: Exercise, store: Store) -> TrailPlan {
        guard case let .trail(low, high) = exercise.modality else {
            return TrailPlan(lowMin: 30, highMin: 40, headline: "Easy miles", reason: "")
        }
        let st = store.state(for: exercise.id)
        let lo = st.cardioLowMin > 0 ? st.cardioLowMin : low
        let hi = st.cardioHighMin > 0 ? st.cardioHighMin : high

        guard let last = store.cardioSessions(exerciseID: exercise.id).first else {
            return TrailPlan(lowMin: lo, highMin: hi,
                             headline: "\(lo)–\(hi) minutes, easy",
                             reason: "Turn location on and the coach can set this window from your actual pace instead of guessing.")
        }
        return TrailPlan(lowMin: lo, highMin: hi,
                         headline: "\(lo)–\(hi) minutes, easy",
                         reason: summary(of: last))
    }

    private static func summary(of s: CardioSession) -> String {
        var parts: [String] = []
        parts.append("Last time: \(Int(s.minutes)) min")
        if s.usedLocation {
            parts.append(String(format: "%.2f mi at %@/mi", s.miles, RunTracker.paceString(s.pace)))
            if s.fadePercent > 12 { parts.append("you faded in the back half") }
            else if s.fadePercent < -8 { parts.append("you finished stronger than you started") }
            else { parts.append("pace held steady") }
        }
        if s.autoPauses > 0 { parts.append("\(s.autoPauses) stop\(s.autoPauses == 1 ? "" : "s")") }
        return parts.joined(separator: " · ") + "."
    }

    /// Reads the run itself — not just the effort rating — to move the target window.
    /// Returns a sentence for the celebration screen.
    @discardableResult
    static func apply(_ session: CardioSession, exercise: Exercise, store: Store) -> String {
        guard case let .trail(baseLow, baseHigh) = exercise.modality else { return "" }
        let st = store.state(for: exercise.id)
        var lo = st.cardioLowMin > 0 ? st.cardioLowMin : baseLow
        var hi = st.cardioHighMin > 0 ? st.cardioHighMin : baseHigh
        let done = Int(session.minutes.rounded())
        var note: String

        if session.finishedShort {
            if !session.usedLocation {
                lo = max(10, lo - 5); hi = max(lo + 10, hi - 5)
                note = "Cut short — dropping the target to \(lo)–\(hi) min so you finish the next one."
            } else if session.fadePercent > 15 || session.autoPauses >= 2 {
                // Pace collapsed: the distance was the problem, not the clock.
                lo = max(10, min(done, lo) - 5)
                hi = max(lo + 10, lo + (baseHigh - baseLow))
                note = "You slowed hard before stopping, so the coach cut the target to \(lo)–\(hi) min. Build it back from there."
            } else {
                // Steady pace right up to the end — they ran out of time, not legs.
                lo = max(15, lo - 5)
                note = "Pace was steady the whole way, so only a small trim to \(lo)–\(hi) min. Your legs weren't the limit."
            }
        } else if session.finishedLong {
            if session.usedLocation && session.fadePercent > 15 {
                note = "You went long but faded badly. Target stays at \(lo)–\(hi) min — hold the pace before adding time."
            } else if session.effort == .easy || session.fadePercent < -5 {
                lo = min(90, lo + 5); hi = min(120, hi + 5)
                note = "Long and steady. Target moves up to \(lo)–\(hi) min."
            } else {
                note = "Nice extra time. Target holds at \(lo)–\(hi) min until it feels easy."
            }
        } else {
            switch session.effort {
            case .easy:
                lo = min(90, lo + 5); hi = min(120, hi + 5)
                note = "That was easy — target moves up to \(lo)–\(hi) min."
            case .failed, .hard:
                if session.usedLocation && session.fadePercent > 20 {
                    note = "You finished the window but faded a lot. Same target, try starting slower."
                } else {
                    note = "Solid work. Same window next time."
                }
            default:
                note = "In the window and holding together. Same target next time."
            }
        }

        st.cardioLowMin = lo
        st.cardioHighMin = hi
        try? store.context.save()
        return note
    }

    // MARK: - Holds

    /// Hold targets move on the effort rating, never on the stopwatch reading —
    /// the timer is there for the user, not for grading.
    static func holdTarget(for exercise: Exercise, store: Store) -> Int {
        guard case let .hold(low, high) = exercise.modality else { return 30 }
        let st = store.state(for: exercise.id)
        if st.holdTarget > 0 { return st.holdTarget }
        return store.profile.experience == .beginner ? low : (low + high) / 2
    }

    static func applyHold(exercise: Exercise, efforts: [Effort], store: Store) -> String? {
        guard case let .hold(low, high) = exercise.modality, !efforts.isEmpty else { return nil }
        let st = store.state(for: exercise.id)
        let current = holdTarget(for: exercise, store: store)
        let avg = Double(efforts.map(\.rawValue).reduce(0, +)) / Double(efforts.count)
        var target = current
        if efforts.contains(.failed) || avg >= 2.4 { target = max(low - 10, current - 5) }
        else if avg <= 0.5 { target = min(high + 60, current + 10) }
        else if avg <= 1.2 { target = min(high + 60, current + 5) }
        guard target != current else { return nil }
        st.holdTarget = max(10, target)
        try? store.context.save()
        return "\(exercise.name) → \(st.holdTarget)s next time"
    }

    // MARK: - Conditioning

    static func conditioningBrief(for exercise: Exercise, store: Store) -> String {
        let st = store.state(for: exercise.id)
        let history = store.conditioningResults(exerciseID: exercise.id)
        switch exercise.modality {
        case .amrap:
            if st.bestRounds > 0 { return "Your best is \(st.bestRounds) rounds. Hold a pace you can keep to the last minute and beat it by one." }
            return "Pick a pace you could hold for the whole clock. The first round should feel too slow."
        case .rounds:
            if let last = history.first { return "Last time: \(RunTracker.clock(last.seconds)) total. Take the full rest — the rounds should stay fast." }
            return "The rest between rounds is prescribed, not optional. It's what keeps each round honest."
        case .forTime:
            if let best = history.map(\.seconds).filter({ $0 > 0 }).min() {
                return "Best: \(RunTracker.clock(best)). Break the reps up early so you never fully stall."
            }
            return "Go steady on round one. Almost everyone starts too fast here."
        default:
            return ""
        }
    }

    @discardableResult
    static func apply(_ result: ConditioningResult, exercise: Exercise, store: Store) -> String? {
        let st = store.state(for: exercise.id)
        switch exercise.modality {
        case .amrap:
            guard result.rounds > st.bestRounds else {
                let splits = result.roundSplits
                if splits.count >= 3, let first = splits.first, let last = splits.last, last > first * 3 / 2 {
                    return "\(exercise.name): your rounds slowed by half by the end — start slower next time"
                }
                return nil
            }
            st.bestRounds = result.rounds
            try? store.context.save()
            return "\(exercise.name): new best at \(result.rounds) rounds"
        case .forTime:
            let prior = store.conditioningResults(exerciseID: exercise.id)
                .filter { $0.persistentModelID != result.persistentModelID }
                .map(\.seconds).filter { $0 > 0 }.min()
            if let prior, result.seconds > 0, result.seconds < prior {
                return "\(exercise.name): \(RunTracker.clock(prior - result.seconds)) faster than last time"
            }
            return nil
        default:
            return nil
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

        let lifts = Library.all.filter { $0.tracksWeight && $0.pattern != .cardio }
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
        let planProgress = Double(store.completed.count) / Double(store.planLength)

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
