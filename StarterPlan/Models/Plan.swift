import Foundation

// MARK: - Static plan definition (hardcoded, 4 weeks x 7 days)

/// How a piece of work is actually performed — each one gets its own screen.
enum Modality: Hashable {
    case reps                                                    // load it, do the reps
    case hold(low: Int, high: Int)                               // seconds under tension
    case trail(lowMin: Int, highMin: Int)                        // GPS-tracked (or blind) time on feet
    case amrap(minutes: Int, movements: [String])                // as many rounds as possible
    case rounds(count: Int, movements: [String], restSeconds: Int)
    case forTime(rounds: Int, movements: [String])

    var isSingleEffort: Bool {
        switch self {
        case .reps, .hold: return false
        default: return true
        }
    }
}

struct Exercise: Identifiable, Hashable {
    let id: String
    let name: String
    let scheme: String        // "3 x 8"
    let sets: Int
    let howTo: String
    let cue: String
    let tracksWeight: Bool
    let modality: Modality

    init(id: String, name: String, scheme: String, sets: Int, howTo: String, cue: String,
         tracksWeight: Bool = true, modality: Modality = .reps) {
        self.id = id; self.name = name; self.scheme = scheme; self.sets = sets
        self.howTo = howTo; self.cue = cue; self.tracksWeight = tracksWeight
        self.modality = modality
    }

    /// Rep target parsed out of the scheme, for the rep tally screen.
    var repTarget: Int {
        let digits = scheme.split(whereSeparator: { !$0.isNumber })
        guard digits.count >= 2, let n = Int(digits[1]) else { return 0 }
        return n
    }
}

enum DayKind: String, Codable {
    case strengthA, trailCardio, rest, strengthB, conditioning, optionalTrail

    var title: String {
        switch self {
        case .strengthA: return "Strength A"
        case .trailCardio: return "Trail Cardio"
        case .rest: return "Rest"
        case .strengthB: return "Strength B"
        case .conditioning: return "Conditioning"
        case .optionalTrail: return "Optional Trail"
        }
    }

    var icon: String {
        switch self {
        case .strengthA, .strengthB: return "dumbbell.fill"
        case .trailCardio, .optionalTrail: return "figure.hiking"
        case .rest: return "moon.zzz.fill"
        case .conditioning: return "flame.fill"
        }
    }

    var isRest: Bool { self == .rest }
}

struct WorkoutDay: Identifiable {
    let week: Int          // 1...4
    let day: Int           // 1 = Monday ... 7 = Sunday
    let kind: DayKind
    let exercises: [Exercise]
    let note: String?

    var id: String { "w\(week)d\(day)" }
    var index: Int { (week - 1) * 7 + (day - 1) }   // 0...27
    var weekdayName: String { ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][day - 1] }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }
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

enum Plan {
    static let strengthA: [Exercise] = [
        Exercise(id: "back_squat", name: "Back Squat", scheme: "3 x 8", sets: 3,
                 howTo: "Rest the bar on your upper back, stand about shoulder width apart, then sit down and back like you're lowering into a chair until your thighs are about parallel to the floor. Push through your whole foot to stand back up.",
                 cue: "Knees track over your toes — don't let them cave inward."),
        Exercise(id: "bench_press", name: "Bench Press", scheme: "3 x 8", sets: 3,
                 howTo: "Lie flat on the bench, grip the bar a bit wider than your shoulders, and lower it to the middle of your chest under control. Press it straight back up until your arms are locked out.",
                 cue: "Tuck your elbows to about 45° instead of flaring them straight out."),
        Exercise(id: "ring_rows", name: "Ring Rows", scheme: "3 x 8-10", sets: 3,
                 howTo: "Hold rings or a bar with straight arms and lean back so your body is a straight line. Pull your chest to your hands, then lower yourself slowly.",
                 cue: "Squeeze your shoulder blades together before your arms bend.", tracksWeight: false),
        Exercise(id: "db_shoulder_press", name: "DB Shoulder Press", scheme: "3 x 10", sets: 3,
                 howTo: "Hold a dumbbell in each hand at shoulder height, palms facing forward. Press them straight overhead until your arms are locked, then lower back to your shoulders.",
                 cue: "Keep your ribs down — don't lean back to finish the press."),
        Exercise(id: "plank", name: "Plank", scheme: "3 x 30-45s", sets: 3,
                 howTo: "Rest on your forearms and toes with your body in one straight line from head to heels. Hold and breathe normally.",
                 cue: "Squeeze your glutes so your hips don't sag or pike up.",
                 tracksWeight: false, modality: .hold(low: 30, high: 45))
    ]

    static let strengthB: [Exercise] = [
        Exercise(id: "rdl", name: "Romanian Deadlift", scheme: "3 x 8", sets: 3,
                 howTo: "Stand holding the bar at your thighs. Push your hips backward and slide the bar down your legs until you feel a stretch behind your thighs, then drive your hips forward to stand tall.",
                 cue: "Back stays flat — the movement comes from your hips, not your lower back."),
        Exercise(id: "pullups", name: "Banded / Jumping Pull-ups", scheme: "3 x 5", sets: 3,
                 howTo: "Use a band under your feet or jump from a box to help you up. Pull until your chin clears the bar, then lower as slowly as you can.",
                 cue: "Start each rep from a full hang with straight arms.", tracksWeight: false),
        Exercise(id: "db_rows", name: "DB Rows", scheme: "3 x 10 / side", sets: 3,
                 howTo: "Put one hand and knee on a bench, hold a dumbbell in the other hand, and let it hang. Pull it up toward your hip, then lower it all the way.",
                 cue: "Pull with your back, not your bicep — lead with the elbow."),
        Exercise(id: "walking_lunges", name: "Walking Lunges", scheme: "3 x 10 / leg", sets: 3,
                 howTo: "Step forward and lower until your back knee nearly touches the ground. Push off your front foot to step straight into the next lunge.",
                 cue: "Keep your torso upright and take a long enough step."),
        Exercise(id: "hollow_hold", name: "Hollow Hold", scheme: "3 x 20-30s", sets: 3,
                 howTo: "Lie on your back, press your lower back into the floor, and lift your shoulders and legs a few inches off the ground. Hold that banana shape.",
                 cue: "If your lower back lifts off the floor, raise your legs higher.",
                 tracksWeight: false, modality: .hold(low: 20, high: 30))
    ]

    static let trailCardio = Exercise(
        id: "trail_cardio", name: "Trail Cardio", scheme: "30-40 min easy", sets: 1,
        howTo: "Head out on a trail or hilly route and keep an easy pace for 30–40 minutes. Walking the steep parts is completely fine.",
        cue: "Easy means you could still hold a conversation the whole time.",
        tracksWeight: false, modality: .trail(lowMin: 30, highMin: 40))

    static let optionalTrail = Exercise(
        id: "optional_trail", name: "Optional Trail Session", scheme: "45-60 min", sets: 1,
        howTo: "A relaxed 45–60 minute hike or jog. This one is a bonus — take it if you feel fresh.",
        cue: "If you're sore or tired, skipping this costs you nothing.",
        tracksWeight: false, modality: .trail(lowMin: 45, highMin: 60))

    static func conditioning(week: Int) -> [Exercise] {
        switch week {
        case 1:
            return [Exercise(id: "cond_w1", name: "Scaled Cindy", scheme: "12 min AMRAP", sets: 1,
                             howTo: "For 12 minutes, keep repeating: 5 ring rows or jumping pull-ups, 10 knee push-ups, 15 air squats. Count how many full rounds you finish.",
                             cue: "Pick a pace you can hold for all 12 minutes — steady beats sprint-and-die.",
                             tracksWeight: false,
                             modality: .amrap(minutes: 12, movements: ["5 ring rows / jumping pull-ups", "10 knee push-ups", "15 air squats"]))]
        case 2:
            return [Exercise(id: "cond_w2", name: "Five Rounds", scheme: "5 rounds, 1 min rest", sets: 1,
                             howTo: "Each round is 10 goblet squats, 8 push-ups and a 20 second plank, then rest one full minute before the next round.",
                             cue: "Actually take the full rest — the rounds should stay fast.",
                             tracksWeight: false,
                             modality: .rounds(count: 5, movements: ["10 goblet squats", "8 push-ups", "20s plank"], restSeconds: 60))]
        case 3:
            return [Exercise(id: "cond_w3", name: "Scaled Cindy", scheme: "15 min AMRAP", sets: 1,
                             howTo: "Same as week 1 but for 15 minutes: 5 ring rows or jumping pull-ups, 10 knee push-ups, 15 air squats, repeat.",
                             cue: "Aim to beat your week 1 round count by at least one.",
                             tracksWeight: false,
                             modality: .amrap(minutes: 15, movements: ["5 ring rows / jumping pull-ups", "10 knee push-ups", "15 air squats"]))]
        default:
            return [Exercise(id: "cond_w4", name: "Three Rounds For Time", scheme: "3 rounds, for time", sets: 1,
                             howTo: "As fast as you safely can: 15 air squats, 12 push-ups, 400m run. Three times through. Note your finish time.",
                             cue: "Break the push-ups up early so you never fully stall.",
                             tracksWeight: false,
                             modality: .forTime(rounds: 3, movements: ["15 air squats", "12 push-ups", "400m run"]))]
        }
    }

    static let days: [WorkoutDay] = (1...4).flatMap { week -> [WorkoutDay] in
        [
            WorkoutDay(week: week, day: 1, kind: .strengthA, exercises: strengthA, note: nil),
            WorkoutDay(week: week, day: 2, kind: .trailCardio, exercises: [trailCardio], note: "Easy aerobic work — build the base."),
            WorkoutDay(week: week, day: 3, kind: .rest, exercises: [], note: "Rest up. Recovery is where you get stronger."),
            WorkoutDay(week: week, day: 4, kind: .strengthB, exercises: strengthB, note: nil),
            WorkoutDay(week: week, day: 5, kind: .conditioning, exercises: conditioning(week: week), note: nil),
            WorkoutDay(week: week, day: 6, kind: .optionalTrail, exercises: [optionalTrail], note: "Bonus day — take it if you feel good."),
            WorkoutDay(week: week, day: 7, kind: .rest, exercises: [], note: "Full rest. See you Monday.")
        ]
    }

    static func day(at index: Int) -> WorkoutDay { days[min(max(index, 0), days.count - 1)] }

    static func exercise(id: String) -> Exercise? {
        let all = strengthA + strengthB + [trailCardio, optionalTrail] + (1...4).flatMap { conditioning(week: $0) }
        return all.first { $0.id == id }
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
