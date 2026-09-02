import Foundation

// MARK: - What the user told us

struct TrainingPreferences: Equatable {
    var goal: TrainingGoal = .general
    var daysPerWeek: Int = 4
    var sessionMinutes: Int = 45
    var equipment: Set<Equipment> = [.bodyweight, .dumbbells]
    var focus: Set<Muscle> = []
    var avoid: Set<JointStress> = []

    var slotCount: Int {
        switch sessionMinutes {
        case ..<25: return 3
        case ..<35: return 4
        case ..<50: return 5
        default: return 6
        }
    }
}

// MARK: - Building the plan

enum PlanGenerator {

    /// Which weekdays get trained, by how many days a week you asked for.
    private static func trainingDays(_ perWeek: Int) -> [Int] {
        switch max(2, min(6, perWeek)) {
        case 2: return [1, 4]
        case 3: return [1, 3, 5]
        case 4: return [1, 2, 4, 5]
        case 5: return [1, 2, 3, 5, 6]
        default: return [1, 2, 3, 4, 5, 6]
        }
    }

    private static func split(_ prefs: TrainingPreferences) -> [DayKind] {
        var kinds: [DayKind]
        switch max(2, min(6, prefs.daysPerWeek)) {
        case 2: kinds = [.fullBody, .fullBody]
        case 3: kinds = [.fullBody, .fullBody, .fullBody]
        case 4: kinds = [.upper, .lower, .upper, .lower]
        case 5: kinds = [.upper, .lower, .push, .pull, .legs]
        default: kinds = [.push, .pull, .legs, .push, .pull, .legs]
        }

        // The goal earns one of the slots.
        switch prefs.goal {
        case .endurance:
            if kinds.count >= 3 { kinds[kinds.count - 1] = .cardio }
            if kinds.count >= 5 { kinds[2] = .cardio }
        case .lean:
            if kinds.count >= 3 { kinds[kinds.count - 1] = .conditioning }
        case .strength, .muscle, .general:
            if kinds.count >= 5 { kinds[kinds.count - 1] = .conditioning }
        }
        return kinds
    }

    /// The movement patterns a session is built from, in order.
    private static func slots(for kind: DayKind) -> [MovementPattern] {
        switch kind {
        case .fullBody: return [.squat, .pushHorizontal, .pullHorizontal, .hinge, .core, .pushVertical]
        case .upper:    return [.pushHorizontal, .pullHorizontal, .pushVertical, .pullVertical, .core, .pullHorizontal]
        case .lower:    return [.squat, .hinge, .lunge, .core, .hinge, .carry]
        case .push:     return [.pushHorizontal, .pushVertical, .pushHorizontal, .core, .pushVertical, .core]
        case .pull:     return [.pullVertical, .pullHorizontal, .pullHorizontal, .core, .pullHorizontal, .carry]
        case .legs:     return [.squat, .hinge, .lunge, .core, .lunge, .carry]
        case .conditioning: return [.conditioning]
        case .cardio:   return [.cardio]
        case .mobility: return [.mobility, .mobility, .mobility]
        case .rest:     return []
        }
    }

    /// Picks the best-fitting movement for a slot, varying the choice week to week.
    static func pick(pattern: MovementPattern,
                     prefs: TrainingPreferences,
                     experience: Experience,
                     exclude: Set<String>,
                     seed: Int) -> Exercise? {
        let candidates = Library.matching(pattern: pattern, equipment: prefs.equipment, avoiding: prefs.avoid)
            .filter { !exclude.contains($0.id) }
        guard !candidates.isEmpty else { return nil }

        func score(_ ex: Exercise) -> Int {
            var s = 0
            for m in ex.primary where prefs.focus.contains(m) { s += 4 }
            for m in ex.secondary where prefs.focus.contains(m) { s += 1 }
            switch experience {
            case .beginner: s -= (ex.difficulty - 1) * 3
            case .some: s -= max(0, ex.difficulty - 2) * 2
            case .experienced: s += ex.difficulty
            }
            return s
        }

        let ranked = candidates.sorted {
            let a = score($0), b = score($1)
            return a == b ? $0.id < $1.id : a > b
        }
        // Rotate through the top few so week 2 doesn't read like week 1.
        let pool = Array(ranked.prefix(max(1, min(3, ranked.count))))
        return pool[seed % pool.count]
    }

    /// Applies the goal's set and rep prescription to a strength movement.
    static func styled(_ ex: Exercise, goal: TrainingGoal) -> Exercise {
        guard case .reps = ex.modality else { return ex }
        let (sets, low, high) = goal.setsAndReps
        let perSide = ex.scheme.contains("/")
        let suffix = perSide ? (ex.scheme.contains("side") ? " / side" : " / leg") : ""
        return ex.adjusted(sets: sets, scheme: "\(sets) x \(low)-\(high)\(suffix)")
    }

    static func session(kind: DayKind,
                        week: Int,
                        day: Int,
                        prefs: TrainingPreferences,
                        experience: Experience) -> WorkoutDay {
        guard kind != .rest else {
            return WorkoutDay(week: week, day: day, kind: .rest, exercises: [],
                              note: "Rest up. Recovery is where the work actually lands.")
        }

        let wanted = kind.isStrength ? prefs.slotCount : slots(for: kind).count
        var chosen: [Exercise] = []
        var used: Set<String> = []
        let patterns = slots(for: kind)

        for (i, pattern) in patterns.enumerated() where chosen.count < wanted {
            guard let ex = pick(pattern: pattern, prefs: prefs, experience: experience,
                                exclude: used, seed: week + i) else { continue }
            used.insert(ex.id)
            chosen.append(kind.isStrength ? styled(ex, goal: prefs.goal) : ex)
        }

        // A focus muscle that never came up gets an accessory on the end.
        if kind.isStrength, chosen.count < wanted + 1,
           let missing = prefs.focus.first(where: { m in !chosen.contains { $0.primary.contains(m) } }) {
            let accessory = Library.all
                .filter { $0.primary.contains(missing) && !used.contains($0.id) }
                .filter { Set($0.equipment).isSubset(of: prefs.equipment.union([.bodyweight])) }
                .filter { Set($0.stress).isDisjoint(with: prefs.avoid) }
                .min { $0.difficulty < $1.difficulty }
            if let accessory { chosen.append(styled(accessory, goal: prefs.goal)) }
        }

        let note: String?
        switch kind {
        case .cardio: note = "Easy aerobic work — the base everything else sits on."
        case .conditioning: note = "Short and sharp. Pace it so the last round looks like the first."
        case .mobility: note = "Slow and easy. This is maintenance, not training."
        default: note = nil
        }

        return WorkoutDay(week: week, day: day, kind: kind, exercises: chosen, note: note)
    }

    /// The full four-week plan, 28 slots, rest days included.
    static func build(_ prefs: TrainingPreferences, experience: Experience) -> [WorkoutDay] {
        let days = trainingDays(prefs.daysPerWeek)
        let kinds = split(prefs)
        var out: [WorkoutDay] = []

        for week in 1...4 {
            for weekday in 1...7 {
                if let slot = days.firstIndex(of: weekday) {
                    let kind = kinds[min(slot, kinds.count - 1)]
                    out.append(session(kind: kind, week: week, day: weekday, prefs: prefs, experience: experience))
                } else {
                    out.append(WorkoutDay(week: week, day: weekday, kind: .rest, exercises: [],
                                          note: "Rest up. Recovery is where the work actually lands."))
                }
            }
        }
        return out
    }
}

// MARK: - Mood

enum Mood: String, CaseIterable, Identifiable, Codable {
    case fresh, normal, low, sore, rushed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fresh: return "Fresh"
        case .normal: return "Normal"
        case .low: return "Low energy"
        case .sore: return "Sore"
        case .rushed: return "No time"
        }
    }

    var icon: String {
        switch self {
        case .fresh: return "bolt.fill"
        case .normal: return "hand.thumbsup.fill"
        case .low: return "battery.25"
        case .sore: return "bandage.fill"
        case .rushed: return "timer"
        }
    }

    var prompt: String {
        switch self {
        case .fresh: return "Good. Let's use it."
        case .normal: return "Then let's get it done."
        case .low: return "Something is better than nothing. Pick the small one."
        case .sore: return "Move it out rather than pushing through it."
        case .rushed: return "Fifteen minutes still counts."
        }
    }
}

// MARK: - The daily choice

struct SessionOption: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let badge: String
    let icon: String
    let session: WorkoutDay
    let isRecommended: Bool

    var minutes: Int { session.estimatedMinutes }
}

enum SessionMenu {

    /// Three real sessions for today. Never "workout or don't" — always "which one".
    static func options(for day: WorkoutDay,
                        mood: Mood,
                        prefs: TrainingPreferences,
                        experience: Experience) -> [SessionOption] {
        if day.kind.isRest { return restOptions(for: day, mood: mood, prefs: prefs, experience: experience) }

        let planned = SessionOption(
            title: day.title,
            subtitle: "\(day.exercises.count) exercises · what your plan has for today",
            badge: "THE PLAN", icon: day.kind.icon,
            session: day, isRecommended: mood == .normal || mood == .fresh)

        let short = trimmed(day, to: mood == .rushed ? 2 : 3,
                            title: mood == .rushed ? "Express \(day.kind.title)" : "\(day.kind.title), lighter")
        let shortOption = SessionOption(
            title: short.title,
            subtitle: mood == .rushed ? "The two that matter most, nothing else" : "Same muscles, less of it",
            badge: mood == .rushed ? "FAST" : "EASIER", icon: "timer",
            session: short, isRecommended: mood == .low || mood == .rushed)

        let bigger = extended(day, prefs: prefs, experience: experience)
        let biggerOption = SessionOption(
            title: "\(day.kind.title) +",
            subtitle: "One extra movement and a conditioning finisher",
            badge: "TURN IT UP", icon: "flame.fill",
            session: bigger, isRecommended: false)

        let flavour: SessionOption
        switch mood {
        case .sore:
            flavour = SessionOption(title: "Move it out", subtitle: "Mobility and an easy walk instead",
                                    badge: "RECOVERY", icon: "figure.flexibility",
                                    session: recovery(for: day, prefs: prefs, experience: experience),
                                    isRecommended: true)
        case .fresh:
            flavour = biggerOption
        case .rushed:
            flavour = SessionOption(title: "Quick burner", subtitle: "One conditioning piece, twelve minutes",
                                    badge: "CONDITIONING", icon: "flame.fill",
                                    session: conditioning(for: day, prefs: prefs, experience: experience),
                                    isRecommended: false)
        case .low, .normal:
            flavour = SessionOption(title: "Get outside", subtitle: "Easy cardio instead of the weights",
                                    badge: "CARDIO", icon: "figure.hiking",
                                    session: cardio(for: day, prefs: prefs, experience: experience),
                                    isRecommended: false)
        }

        switch mood {
        case .fresh:  return [planned, biggerOption, shortOption]
        case .normal: return [planned, shortOption, flavour]
        case .low:    return [shortOption, flavour, planned]
        case .sore:   return [flavour, shortOption, planned]
        case .rushed: return [shortOption, flavour, planned]
        }
    }

    private static func restOptions(for day: WorkoutDay, mood: Mood,
                                    prefs: TrainingPreferences, experience: Experience) -> [SessionOption] {
        let rest = SessionOption(
            title: "Take the rest", subtitle: "Log it and keep the streak — recovery is part of the plan",
            badge: "REST DAY", icon: "moon.zzz.fill",
            session: day, isRecommended: mood != .fresh)

        let movers = SessionOption(
            title: "Easy movers", subtitle: "Mobility flow, nothing that costs you tomorrow",
            badge: "OPTIONAL", icon: "figure.flexibility",
            session: recovery(for: day, prefs: prefs, experience: experience),
            isRecommended: mood == .sore)

        let walk = SessionOption(
            title: "Go for a walk", subtitle: "Twenty easy minutes outside",
            badge: "OPTIONAL", icon: "figure.walk",
            session: cardio(for: day, prefs: prefs, experience: experience, easy: true),
            isRecommended: mood == .fresh)

        return [rest, movers, walk]
    }

    // MARK: Variants

    private static func trimmed(_ day: WorkoutDay, to count: Int, title: String) -> WorkoutDay {
        let kept = Array(day.exercises.prefix(max(1, count)))
        let lighter = kept.map { ex -> Exercise in
            guard case .reps = ex.modality, ex.sets > 2 else { return ex }
            return ex.adjusted(sets: ex.sets - 1, scheme: ex.scheme)
        }
        return day.replacing(exercises: lighter, title: title,
                             note: "Trimmed on purpose. Finishing something beats skipping everything.")
    }

    private static func extended(_ day: WorkoutDay, prefs: TrainingPreferences, experience: Experience) -> WorkoutDay {
        var list = day.exercises
        let used = Set(list.map(\.id))
        if let finisher = Library.matching(pattern: .conditioning, equipment: prefs.equipment, avoiding: prefs.avoid)
            .first(where: { !used.contains($0.id) }) {
            list.append(finisher)
        }
        return day.replacing(exercises: list, title: "\(day.kind.title) +",
                             note: "You said you felt good. Prove it.")
    }

    private static func recovery(for day: WorkoutDay, prefs: TrainingPreferences, experience: Experience) -> WorkoutDay {
        let flows = Library.mobility
        return day.replacing(exercises: flows, title: "Move it out",
                             note: "Slow, easy, no load. This counts as your session.", kind: .mobility)
    }

    private static func cardio(for day: WorkoutDay, prefs: TrainingPreferences,
                               experience: Experience, easy: Bool = false) -> WorkoutDay {
        let id = easy ? "easy_walk" : "trail_cardio"
        let ex = Library.exercise(id: id) ?? Library.cardioWork[0]
        return day.replacing(exercises: [ex], title: easy ? "Easy walk" : "Get outside",
                             note: "Time on your feet. Keep it conversational.", kind: .cardio)
    }

    private static func conditioning(for day: WorkoutDay, prefs: TrainingPreferences, experience: Experience) -> WorkoutDay {
        let ex = Library.matching(pattern: .conditioning, equipment: prefs.equipment, avoiding: prefs.avoid).first
            ?? Library.conditioning[0]
        return day.replacing(exercises: [ex], title: "Quick burner",
                             note: "One piece, all out, done.", kind: .conditioning)
    }
}

// MARK: - Freestyle extras

enum Freestyle {

    static let durations = [15, 25, 40]

    /// Builds a session outside the plan — for rest-day itches and second helpings.
    static func session(focus: Set<Muscle>,
                        minutes: Int,
                        prefs: TrainingPreferences,
                        experience: Experience) -> WorkoutDay {
        var tuned = prefs
        tuned.focus = focus.isEmpty ? prefs.focus : focus
        tuned.sessionMinutes = minutes

        let regions = Set(tuned.focus.map(\.region))
        let patterns: [MovementPattern]
        if focus.isEmpty {
            patterns = [.squat, .pushHorizontal, .pullHorizontal, .core, .hinge]
        } else if regions == [.lower] {
            patterns = [.squat, .hinge, .lunge, .core, .lunge]
        } else if regions == [.core] {
            patterns = [.core, .core, .carry, .core, .hinge]
        } else if regions == [.upper] {
            patterns = [.pushHorizontal, .pullHorizontal, .pushVertical, .pullVertical, .core]
        } else {
            patterns = [.squat, .pushHorizontal, .pullHorizontal, .core, .hinge]
        }

        let wanted = tuned.slotCount
        var chosen: [Exercise] = []
        var used: Set<String> = []
        for (i, pattern) in patterns.enumerated() where chosen.count < wanted {
            // Prefer something that actually hits what they asked for.
            let candidates = Library.matching(pattern: pattern, equipment: tuned.equipment, avoiding: tuned.avoid)
                .filter { !used.contains($0.id) }
            let onTarget = candidates.filter { ex in ex.primary.contains { tuned.focus.contains($0) } }
            let pool = onTarget.isEmpty ? candidates : onTarget
            guard let ex = pool.min(by: { abs($0.difficulty - level(experience)) < abs($1.difficulty - level(experience)) })
            else { continue }
            used.insert(ex.id)
            chosen.append(PlanGenerator.styled(ex, goal: tuned.goal))
            _ = i
        }

        // Never hand back an empty session.
        if chosen.isEmpty { chosen = [Library.exercise(id: "air_squat")!, Library.exercise(id: "pushup")!] }

        let title = focus.isEmpty ? "Extra session" : titleFor(focus)
        return WorkoutDay.extra(kind: .fullBody, title: title, exercises: chosen,
                                note: "Extra session — logged in full, and it doesn't touch your plan.")
    }

    static func mobilitySession() -> WorkoutDay {
        WorkoutDay.extra(kind: .mobility, title: "Mobility flow", exercises: Library.mobility,
                         note: "Easy movement. Counts as a session, costs you nothing tomorrow.")
    }

    private static func level(_ e: Experience) -> Int {
        switch e {
        case .beginner: return 1
        case .some: return 2
        case .experienced: return 3
        }
    }

    private static func titleFor(_ focus: Set<Muscle>) -> String {
        let regions = Set(focus.map(\.region))
        if regions == [.lower] { return "Legs, extra" }
        if regions == [.upper] { return "Upper body, extra" }
        if regions == [.core] { return "Core, extra" }
        if focus.count == 1, let m = focus.first { return "\(m.plainLabel), extra" }
        return "Extra session"
    }
}
