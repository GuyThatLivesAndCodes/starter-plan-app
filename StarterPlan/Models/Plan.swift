import Foundation

/// How a piece of work is actually performed — each one gets its own screen.
enum Modality: Hashable {
    case reps
    case hold(low: Int, high: Int)
    case trail(lowMin: Int, highMin: Int)
    case amrap(minutes: Int, movements: [String])
    case rounds(count: Int, movements: [String], restSeconds: Int)
    case forTime(rounds: Int, movements: [String])

    var isSingleEffort: Bool {
        switch self {
        case .reps, .hold: return false
        default: return true
        }
    }
}

enum DayKind: String, Codable {
    case fullBody, upper, lower, push, pull, legs
    case conditioning, cardio, mobility, rest

    var title: String {
        switch self {
        case .fullBody: return "Full Body"
        case .upper: return "Upper Body"
        case .lower: return "Lower Body"
        case .push: return "Push Day"
        case .pull: return "Pull Day"
        case .legs: return "Leg Day"
        case .conditioning: return "Conditioning"
        case .cardio: return "Cardio"
        case .mobility: return "Mobility"
        case .rest: return "Rest"
        }
    }

    var icon: String {
        switch self {
        case .fullBody, .upper, .push, .pull: return "dumbbell.fill"
        case .lower, .legs: return "figure.strengthtraining.functional"
        case .cardio: return "figure.hiking"
        case .conditioning: return "flame.fill"
        case .mobility: return "figure.flexibility"
        case .rest: return "moon.zzz.fill"
        }
    }

    var isRest: Bool { self == .rest }
    var isStrength: Bool {
        switch self {
        case .fullBody, .upper, .lower, .push, .pull, .legs: return true
        default: return false
        }
    }
}

struct WorkoutDay: Identifiable {
    let week: Int
    let day: Int              // 1 = Monday … 7 = Sunday
    let kind: DayKind
    let exercises: [Exercise]
    let note: String?
    /// Position in the 28-day plan. Nil for freestyle and extra sessions.
    let planIndex: Int?
    /// Overrides the kind's title when a session was generated for a mood or focus.
    let titleOverride: String?

    /// A day that belongs to the 28-day plan.
    init(week: Int, day: Int, kind: DayKind, exercises: [Exercise],
         note: String? = nil, titleOverride: String? = nil) {
        self.week = week; self.day = day; self.kind = kind
        self.exercises = exercises; self.note = note
        self.planIndex = (week - 1) * 7 + (day - 1)
        self.titleOverride = titleOverride
    }

    /// Freestyle and extra sessions live outside the plan and never advance it.
    static func extra(kind: DayKind, title: String, exercises: [Exercise], note: String? = nil) -> WorkoutDay {
        WorkoutDay(unplannedKind: kind, title: title, exercises: exercises, note: note)
    }

    private init(unplannedKind kind: DayKind, title: String, exercises: [Exercise], note: String?) {
        self.week = 1; self.day = 1; self.kind = kind
        self.exercises = exercises; self.note = note
        self.planIndex = nil; self.titleOverride = title
    }

    /// Same session, different exercise list — used when a mood reshapes the day.
    func replacing(exercises newExercises: [Exercise], title: String?,
                   note: String? = nil, kind newKind: DayKind? = nil) -> WorkoutDay {
        let k = newKind ?? kind
        guard let planIndex else {
            return WorkoutDay(unplannedKind: k, title: title ?? self.title, exercises: newExercises, note: note ?? self.note)
        }
        return WorkoutDay(week: planIndex / 7 + 1, day: planIndex % 7 + 1, kind: k,
                          exercises: newExercises, note: note ?? self.note, titleOverride: title)
    }

    var id: String { "w\(week)d\(day)-\(titleOverride ?? kind.rawValue)-\(planIndex.map(String.init) ?? "x")" }
    var index: Int { planIndex ?? -1 }
    var isExtra: Bool { planIndex == nil }
    var title: String { titleOverride ?? kind.title }
    var weekdayName: String { ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][max(0, min(6, day - 1))] }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }

    /// Muscles this session actually loads, strongest first.
    var muscleLoad: [Muscle: Double] {
        var out: [Muscle: Double] = [:]
        for ex in exercises {
            let volume = Double(ex.sets)
            for m in ex.primary { out[m, default: 0] += volume }
            for m in ex.secondary { out[m, default: 0] += volume * 0.4 }
        }
        return out
    }

    var estimatedMinutes: Int {
        exercises.reduce(0) { total, ex in
            switch ex.modality {
            case .reps: return total + ex.sets * 3
            case .hold: return total + ex.sets * 2
            case .trail(let low, _): return total + low
            case .amrap(let m, _): return total + m + 4
            case .rounds(let c, _, let rest): return total + c * (rest / 60 + 2)
            case .forTime(let r, _): return total + r * 4
            }
        }
    }

    var xpValue: Int {
        exercises.reduce(0) { total, ex in
            switch ex.modality {
            case .reps, .hold: return total + ex.sets * 10
            case .trail: return total + 60
            case .amrap, .rounds, .forTime: return total + 80
            }
        }
    }
}

enum Copy {
    static let setDone = ["Nice work!", "That's it!", "Clean rep.", "Strong.", "Keep rolling.", "Locked in."]
    static let exerciseDone = ["Exercise crushed 💪", "Done and dusted!", "On to the next.", "That's one down."]
    static func streak(_ n: Int) -> String {
        switch n {
        case 0: return "Start your streak today"
        case 1: return "Day one. Let's go."
        case 2...4: return "\(n) days in a row!"
        case 5...9: return "\(n) days — you're on fire 🔥"
        default: return "\(n) day streak. Unstoppable."
        }
    }
}
