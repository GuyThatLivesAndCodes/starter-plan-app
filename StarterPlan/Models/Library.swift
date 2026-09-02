import Foundation

// MARK: - Anatomy

enum Muscle: String, CaseIterable, Identifiable, Codable {
    case chest, frontDelts, sideDelts, rearDelts, biceps, triceps, forearms
    case lats, traps, lowerBack, abs, obliques, glutes, quads, hamstrings, calves

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chest: return "Chest"
        case .frontDelts: return "Front shoulders"
        case .sideDelts: return "Side shoulders"
        case .rearDelts: return "Rear shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .lats: return "Lats"
        case .traps: return "Upper back"
        case .lowerBack: return "Lower back"
        case .abs: return "Abs"
        case .obliques: return "Obliques"
        case .glutes: return "Glutes"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .calves: return "Calves"
        }
    }

    /// Plain-language name for people who don't speak gym.
    var plainLabel: String {
        switch self {
        case .lats: return "Back (sides)"
        case .traps: return "Back (upper)"
        case .lowerBack: return "Lower back"
        case .frontDelts, .sideDelts, .rearDelts: return "Shoulders"
        default: return label
        }
    }

    /// Which figure the muscle is drawn on.
    var isBackView: Bool {
        switch self {
        case .lats, .traps, .lowerBack, .glutes, .hamstrings, .rearDelts, .triceps: return true
        default: return false
        }
    }

    /// Coarse grouping used by the questionnaire and the coach.
    var region: Region {
        switch self {
        case .chest, .frontDelts, .sideDelts, .rearDelts, .triceps, .biceps, .forearms, .lats, .traps:
            return .upper
        case .abs, .obliques, .lowerBack:
            return .core
        case .glutes, .quads, .hamstrings, .calves:
            return .lower
        }
    }

    enum Region: String, CaseIterable, Identifiable {
        case upper, core, lower
        var id: String { rawValue }
        var label: String {
            switch self {
            case .upper: return "Upper body"
            case .core: return "Core"
            case .lower: return "Lower body"
            }
        }
    }
}

enum MovementPattern: String, CaseIterable, Codable {
    case squat, hinge, lunge
    case pushHorizontal, pushVertical, pullHorizontal, pullVertical
    case core, carry, conditioning, cardio, mobility

    var label: String {
        switch self {
        case .squat: return "Squat"
        case .hinge: return "Hinge"
        case .lunge: return "Single leg"
        case .pushHorizontal: return "Horizontal push"
        case .pushVertical: return "Overhead push"
        case .pullHorizontal: return "Row"
        case .pullVertical: return "Pull-up"
        case .core: return "Core"
        case .carry: return "Carry"
        case .conditioning: return "Conditioning"
        case .cardio: return "Cardio"
        case .mobility: return "Mobility"
        }
    }
}

enum Equipment: String, CaseIterable, Identifiable, Codable {
    case bodyweight, dumbbells, barbell, bench, pullupBar, bands, kettlebell

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bodyweight: return "Just me"
        case .dumbbells: return "Dumbbells"
        case .barbell: return "Barbell"
        case .bench: return "Bench"
        case .pullupBar: return "Bar or rings"
        case .bands: return "Resistance bands"
        case .kettlebell: return "Kettlebell"
        }
    }

    var icon: String {
        switch self {
        case .bodyweight: return "figure.stand"
        case .dumbbells: return "dumbbell.fill"
        case .barbell: return "figure.strengthtraining.traditional"
        case .bench: return "bed.double.fill"
        case .pullupBar: return "figure.play"
        case .bands: return "line.diagonal"
        case .kettlebell: return "bag.fill"
        }
    }
}

/// Areas people commonly need to work around.
enum JointStress: String, CaseIterable, Identifiable, Codable {
    case knees, lowerBack, shoulders, wrists

    var id: String { rawValue }
    var label: String {
        switch self {
        case .knees: return "Knees"
        case .lowerBack: return "Lower back"
        case .shoulders: return "Shoulders"
        case .wrists: return "Wrists"
        }
    }
}

// MARK: - Goals

enum TrainingGoal: String, CaseIterable, Identifiable, Codable {
    case strength, muscle, lean, endurance, general

    var id: String { rawValue }

    var label: String {
        switch self {
        case .strength: return "Get stronger"
        case .muscle: return "Build muscle"
        case .lean: return "Lean out"
        case .endurance: return "Build endurance"
        case .general: return "Feel better day to day"
        }
    }

    var blurb: String {
        switch self {
        case .strength: return "Heavier weight, fewer reps, longer rest"
        case .muscle: return "Moderate weight, more reps, steady volume"
        case .lean: return "Full body work with conditioning finishers"
        case .endurance: return "More cardio, lighter strength work"
        case .general: return "A balanced mix, nothing extreme"
        }
    }

    /// Sets and rep range the generator applies to strength slots.
    var setsAndReps: (sets: Int, low: Int, high: Int) {
        switch self {
        case .strength: return (4, 4, 6)
        case .muscle: return (3, 8, 12)
        case .lean: return (3, 10, 15)
        case .endurance: return (2, 12, 15)
        case .general: return (3, 8, 10)
        }
    }

    var restSeconds: Int {
        switch self {
        case .strength: return 150
        case .muscle: return 105
        case .lean, .endurance: return 60
        case .general: return 90
        }
    }
}

// MARK: - Exercise

struct Exercise: Identifiable, Hashable {
    let id: String
    let name: String
    let scheme: String
    let sets: Int
    let howTo: String
    let cue: String
    let tracksWeight: Bool
    let modality: Modality
    let pattern: MovementPattern
    let primary: [Muscle]
    let secondary: [Muscle]
    let equipment: [Equipment]
    let stress: [JointStress]
    let difficulty: Int          // 1 easy … 3 demanding

    init(id: String, name: String, scheme: String, sets: Int, howTo: String, cue: String,
         tracksWeight: Bool = true, modality: Modality = .reps,
         pattern: MovementPattern = .core,
         primary: [Muscle] = [], secondary: [Muscle] = [],
         equipment: [Equipment] = [.bodyweight], stress: [JointStress] = [], difficulty: Int = 1) {
        self.id = id; self.name = name; self.scheme = scheme; self.sets = sets
        self.howTo = howTo; self.cue = cue; self.tracksWeight = tracksWeight
        self.modality = modality; self.pattern = pattern
        self.primary = primary; self.secondary = secondary
        self.equipment = equipment; self.stress = stress; self.difficulty = difficulty
    }

    var repTarget: Int {
        let digits = scheme.split(whereSeparator: { !$0.isNumber })
        guard digits.count >= 2, let n = Int(digits[1]) else { return 0 }
        return n
    }

    var muscles: [Muscle] { primary + secondary }

    /// Re-scheme this movement for a goal, keeping everything else intact.
    func adjusted(sets newSets: Int, scheme newScheme: String) -> Exercise {
        Exercise(id: id, name: name, scheme: newScheme, sets: newSets, howTo: howTo, cue: cue,
                 tracksWeight: tracksWeight, modality: modality, pattern: pattern,
                 primary: primary, secondary: secondary, equipment: equipment,
                 stress: stress, difficulty: difficulty)
    }
}

// MARK: - The library

enum Library {

    static let all: [Exercise] = squats + hinges + lunges + horizontalPush + verticalPush
        + horizontalPull + verticalPull + core + conditioning + cardioWork + mobility

    static func exercise(id: String) -> Exercise? { byID[id] }

    private static let byID: [String: Exercise] = {
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }()

    static func matching(pattern: MovementPattern, equipment: Set<Equipment>, avoiding: Set<JointStress>) -> [Exercise] {
        all.filter {
            $0.pattern == pattern
            && Set($0.equipment).isSubset(of: equipment.union([.bodyweight]))
            && Set($0.stress).isDisjoint(with: avoiding)
        }
    }

    // MARK: Squat

    static let squats: [Exercise] = [
        Exercise(id: "back_squat", name: "Back Squat", scheme: "3 x 8", sets: 3,
                 howTo: "Rest the bar on your upper back, stand about shoulder width apart, then sit down and back like you're lowering into a chair until your thighs are about parallel to the floor. Push through your whole foot to stand back up.",
                 cue: "Knees track over your toes — don't let them cave inward.",
                 pattern: .squat, primary: [.quads, .glutes], secondary: [.abs, .lowerBack, .hamstrings],
                 equipment: [.barbell], stress: [.knees, .lowerBack], difficulty: 3),
        Exercise(id: "goblet_squat", name: "Goblet Squat", scheme: "3 x 10", sets: 3,
                 howTo: "Hold one dumbbell or kettlebell against your chest with both hands. Sit down between your knees, keeping your chest tall, then stand back up.",
                 cue: "Elbows stay inside your knees at the bottom.",
                 pattern: .squat, primary: [.quads, .glutes], secondary: [.abs],
                 equipment: [.dumbbells], stress: [.knees], difficulty: 1),
        Exercise(id: "air_squat", name: "Bodyweight Squat", scheme: "3 x 15", sets: 3,
                 howTo: "Feet about shoulder width, arms out in front for balance. Sit down and back until your thighs are parallel, then stand.",
                 cue: "Push your knees out as you come up.",
                 tracksWeight: false, pattern: .squat, primary: [.quads, .glutes], secondary: [.abs],
                 equipment: [.bodyweight], stress: [.knees], difficulty: 1),
        Exercise(id: "kb_front_squat", name: "Kettlebell Front Squat", scheme: "3 x 8", sets: 3,
                 howTo: "Rack a kettlebell against your chest and shoulder. Squat down under control and drive back up.",
                 cue: "Keep your wrist straight — the bell rests on your forearm.",
                 pattern: .squat, primary: [.quads, .glutes], secondary: [.abs, .frontDelts],
                 equipment: [.kettlebell], stress: [.knees, .wrists], difficulty: 2)
    ]

    // MARK: Hinge

    static let hinges: [Exercise] = [
        Exercise(id: "rdl", name: "Romanian Deadlift", scheme: "3 x 8", sets: 3,
                 howTo: "Stand holding the bar at your thighs. Push your hips backward and slide the bar down your legs until you feel a stretch behind your thighs, then drive your hips forward to stand tall.",
                 cue: "Back stays flat — the movement comes from your hips, not your lower back.",
                 pattern: .hinge, primary: [.hamstrings, .glutes], secondary: [.lowerBack, .traps],
                 equipment: [.barbell], stress: [.lowerBack], difficulty: 2),
        Exercise(id: "db_rdl", name: "Dumbbell Romanian Deadlift", scheme: "3 x 10", sets: 3,
                 howTo: "Hold a dumbbell in each hand in front of your thighs. Push your hips back and lower the weights along your legs, then squeeze your glutes to stand.",
                 cue: "Soft knees, long spine. Feel it behind the thighs, not in the low back.",
                 pattern: .hinge, primary: [.hamstrings, .glutes], secondary: [.lowerBack],
                 equipment: [.dumbbells], stress: [.lowerBack], difficulty: 1),
        Exercise(id: "kb_swing", name: "Kettlebell Swing", scheme: "3 x 15", sets: 3,
                 howTo: "Hinge at the hips and hike the bell back between your legs, then snap your hips forward to float it up to chest height. Let it fall back and repeat.",
                 cue: "It's a hip snap, not an arm lift — the bell floats, you don't raise it.",
                 pattern: .hinge, primary: [.glutes, .hamstrings], secondary: [.lowerBack, .abs, .traps],
                 equipment: [.kettlebell], stress: [.lowerBack], difficulty: 2),
        Exercise(id: "glute_bridge", name: "Glute Bridge", scheme: "3 x 15", sets: 3,
                 howTo: "Lie on your back, knees bent, feet flat. Drive through your heels to lift your hips until your body is a straight line from knees to shoulders, then lower.",
                 cue: "Squeeze your glutes at the top and hold for a second.",
                 tracksWeight: false, pattern: .hinge, primary: [.glutes], secondary: [.hamstrings, .abs],
                 equipment: [.bodyweight], difficulty: 1),
        Exercise(id: "good_morning", name: "Banded Good Morning", scheme: "3 x 12", sets: 3,
                 howTo: "Loop a band under your feet and over the back of your neck. Hinge forward at the hips against the band, then stand back up.",
                 cue: "Chest stays proud the whole way down.",
                 tracksWeight: false, pattern: .hinge, primary: [.hamstrings, .glutes], secondary: [.lowerBack],
                 equipment: [.bands], stress: [.lowerBack], difficulty: 1)
    ]

    // MARK: Lunge / single leg

    static let lunges: [Exercise] = [
        Exercise(id: "walking_lunges", name: "Walking Lunges", scheme: "3 x 10 / leg", sets: 3,
                 howTo: "Step forward and lower until your back knee nearly touches the ground. Push off your front foot to step straight into the next lunge.",
                 cue: "Keep your torso upright and take a long enough step.",
                 pattern: .lunge, primary: [.quads, .glutes], secondary: [.hamstrings, .abs],
                 equipment: [.bodyweight], stress: [.knees], difficulty: 2),
        Exercise(id: "split_squat", name: "Split Squat", scheme: "3 x 8 / leg", sets: 3,
                 howTo: "Stand in a long stride. Lower straight down until your back knee is just off the floor, then drive back up through the front foot.",
                 cue: "Straight up and down — don't drift forward.",
                 pattern: .lunge, primary: [.quads, .glutes], secondary: [.hamstrings],
                 equipment: [.bodyweight], stress: [.knees], difficulty: 1),
        Exercise(id: "step_up", name: "Step-ups", scheme: "3 x 10 / leg", sets: 3,
                 howTo: "Put one foot on a bench or sturdy box. Drive through that heel to stand up on it, then lower slowly under control.",
                 cue: "Don't push off the back foot — the working leg does everything.",
                 pattern: .lunge, primary: [.quads, .glutes], secondary: [.calves],
                 equipment: [.bench], stress: [.knees], difficulty: 2),
        Exercise(id: "calf_raise", name: "Calf Raises", scheme: "3 x 20", sets: 3,
                 howTo: "Stand tall, push up onto the balls of your feet as high as you can, pause, then lower slowly.",
                 cue: "Full range — all the way up, all the way down.",
                 tracksWeight: false, pattern: .lunge, primary: [.calves], secondary: [],
                 equipment: [.bodyweight], difficulty: 1)
    ]

    // MARK: Horizontal push

    static let horizontalPush: [Exercise] = [
        Exercise(id: "bench_press", name: "Bench Press", scheme: "3 x 8", sets: 3,
                 howTo: "Lie flat on the bench, grip the bar a bit wider than your shoulders, and lower it to the middle of your chest under control. Press it straight back up until your arms are locked out.",
                 cue: "Tuck your elbows to about 45° instead of flaring them straight out.",
                 pattern: .pushHorizontal, primary: [.chest], secondary: [.triceps, .frontDelts],
                 equipment: [.barbell, .bench], stress: [.shoulders], difficulty: 2),
        Exercise(id: "db_bench", name: "Dumbbell Bench Press", scheme: "3 x 10", sets: 3,
                 howTo: "Lie on a bench holding a dumbbell in each hand at chest level. Press them up until your arms are straight, then lower slowly.",
                 cue: "Lower until you feel a stretch across your chest, no further.",
                 pattern: .pushHorizontal, primary: [.chest], secondary: [.triceps, .frontDelts],
                 equipment: [.dumbbells, .bench], stress: [.shoulders], difficulty: 1),
        Exercise(id: "pushup", name: "Push-ups", scheme: "3 x 12", sets: 3,
                 howTo: "Hands under your shoulders, body in one straight line. Lower your chest to just above the floor, then press back up.",
                 cue: "Squeeze your glutes so your hips don't sag.",
                 tracksWeight: false, pattern: .pushHorizontal, primary: [.chest], secondary: [.triceps, .frontDelts, .abs],
                 equipment: [.bodyweight], stress: [.wrists], difficulty: 2),
        Exercise(id: "knee_pushup", name: "Knee Push-ups", scheme: "3 x 12", sets: 3,
                 howTo: "Same as a push-up but with your knees on the floor. Keep a straight line from knees to head.",
                 cue: "Hips stay in line — don't pike them up.",
                 tracksWeight: false, pattern: .pushHorizontal, primary: [.chest], secondary: [.triceps, .frontDelts],
                 equipment: [.bodyweight], stress: [.wrists], difficulty: 1),
        Exercise(id: "band_press", name: "Band Chest Press", scheme: "3 x 15", sets: 3,
                 howTo: "Anchor a band behind you at chest height, hold an end in each hand, and press forward until your arms are straight.",
                 cue: "Control the way back — don't let the band snap you.",
                 tracksWeight: false, pattern: .pushHorizontal, primary: [.chest], secondary: [.triceps, .frontDelts],
                 equipment: [.bands], difficulty: 1)
    ]

    // MARK: Vertical push

    static let verticalPush: [Exercise] = [
        Exercise(id: "db_shoulder_press", name: "DB Shoulder Press", scheme: "3 x 10", sets: 3,
                 howTo: "Hold a dumbbell in each hand at shoulder height, palms facing forward. Press them straight overhead until your arms are locked, then lower back to your shoulders.",
                 cue: "Keep your ribs down — don't lean back to finish the press.",
                 pattern: .pushVertical, primary: [.frontDelts, .sideDelts], secondary: [.triceps, .abs],
                 equipment: [.dumbbells], stress: [.shoulders], difficulty: 2),
        Exercise(id: "pike_pushup", name: "Pike Push-ups", scheme: "3 x 8", sets: 3,
                 howTo: "Start in a push-up position then walk your feet in so your hips are high. Lower the top of your head toward the floor and press back up.",
                 cue: "Elbows point back and slightly out, not straight sideways.",
                 tracksWeight: false, pattern: .pushVertical, primary: [.frontDelts, .sideDelts], secondary: [.triceps],
                 equipment: [.bodyweight], stress: [.shoulders, .wrists], difficulty: 2),
        Exercise(id: "lateral_raise", name: "Lateral Raises", scheme: "3 x 15", sets: 3,
                 howTo: "Hold light dumbbells at your sides. Lift them out sideways to shoulder height with slightly bent elbows, then lower slowly.",
                 cue: "Light weight. If you're swinging, it's too heavy.",
                 pattern: .pushVertical, primary: [.sideDelts], secondary: [.traps],
                 equipment: [.dumbbells], stress: [.shoulders], difficulty: 1),
        Exercise(id: "band_overhead", name: "Band Overhead Press", scheme: "3 x 15", sets: 3,
                 howTo: "Stand on the middle of a band, hold the ends at your shoulders, and press straight overhead.",
                 cue: "Press slightly back, so the band finishes over your ears.",
                 tracksWeight: false, pattern: .pushVertical, primary: [.frontDelts, .sideDelts], secondary: [.triceps],
                 equipment: [.bands], stress: [.shoulders], difficulty: 1)
    ]

    // MARK: Horizontal pull

    static let horizontalPull: [Exercise] = [
        Exercise(id: "db_rows", name: "DB Rows", scheme: "3 x 10 / side", sets: 3,
                 howTo: "Put one hand and knee on a bench, hold a dumbbell in the other hand, and let it hang. Pull it up toward your hip, then lower it all the way.",
                 cue: "Pull with your back, not your bicep — lead with the elbow.",
                 pattern: .pullHorizontal, primary: [.lats, .traps], secondary: [.biceps, .rearDelts, .forearms],
                 equipment: [.dumbbells], difficulty: 1),
        Exercise(id: "ring_rows", name: "Ring Rows", scheme: "3 x 10", sets: 3,
                 howTo: "Hold rings or a bar with straight arms and lean back so your body is a straight line. Pull your chest to your hands, then lower yourself slowly.",
                 cue: "Squeeze your shoulder blades together before your arms bend.",
                 tracksWeight: false, pattern: .pullHorizontal, primary: [.lats, .traps], secondary: [.biceps, .rearDelts],
                 equipment: [.pullupBar], difficulty: 1),
        Exercise(id: "band_row", name: "Band Row", scheme: "3 x 15", sets: 3,
                 howTo: "Anchor a band in front of you at chest height. Pull the handles to your ribs, squeezing your shoulder blades, then reach back out.",
                 cue: "Elbows brush past your sides, not out wide.",
                 tracksWeight: false, pattern: .pullHorizontal, primary: [.lats, .traps], secondary: [.biceps, .rearDelts],
                 equipment: [.bands], difficulty: 1),
        Exercise(id: "db_curl", name: "Dumbbell Curls", scheme: "3 x 12", sets: 3,
                 howTo: "Stand with a dumbbell in each hand, palms forward. Curl them to your shoulders without swinging, then lower slowly.",
                 cue: "Elbows stay pinned at your sides.",
                 pattern: .pullHorizontal, primary: [.biceps], secondary: [.forearms],
                 equipment: [.dumbbells], difficulty: 1),
        Exercise(id: "face_pull", name: "Band Face Pulls", scheme: "3 x 15", sets: 3,
                 howTo: "Anchor a band at face height. Pull the ends toward your forehead, spreading your hands apart as you go.",
                 cue: "Finish with your thumbs pointing behind you.",
                 tracksWeight: false, pattern: .pullHorizontal, primary: [.rearDelts, .traps], secondary: [.biceps],
                 equipment: [.bands], difficulty: 1)
    ]

    // MARK: Vertical pull

    static let verticalPull: [Exercise] = [
        Exercise(id: "pullups", name: "Pull-ups", scheme: "3 x 5", sets: 3,
                 howTo: "Hang from the bar with straight arms. Pull until your chin clears the bar, then lower all the way down under control.",
                 cue: "Start each rep from a full hang.",
                 tracksWeight: false, pattern: .pullVertical, primary: [.lats], secondary: [.biceps, .traps, .forearms],
                 equipment: [.pullupBar], stress: [.shoulders], difficulty: 3),
        Exercise(id: "banded_pullups", name: "Banded / Jumping Pull-ups", scheme: "3 x 5", sets: 3,
                 howTo: "Use a band under your feet or jump from a box to help you up. Pull until your chin clears the bar, then lower as slowly as you can.",
                 cue: "Start each rep from a full hang with straight arms.",
                 tracksWeight: false, pattern: .pullVertical, primary: [.lats], secondary: [.biceps, .traps],
                 equipment: [.pullupBar], difficulty: 2),
        Exercise(id: "band_pulldown", name: "Band Pulldown", scheme: "3 x 15", sets: 3,
                 howTo: "Anchor a band overhead. Kneel or stand and pull the ends down to your chest, then let them rise back slowly.",
                 cue: "Drive your elbows down toward your back pockets.",
                 tracksWeight: false, pattern: .pullVertical, primary: [.lats], secondary: [.biceps, .rearDelts],
                 equipment: [.bands], difficulty: 1),
        Exercise(id: "dead_hang", name: "Dead Hang", scheme: "3 x 30s", sets: 3,
                 howTo: "Hang from a bar with straight arms and relaxed shoulders for as long as you can hold on.",
                 cue: "Breathe. Let your shoulders decompress.",
                 tracksWeight: false, modality: .hold(low: 20, high: 45),
                 pattern: .pullVertical, primary: [.forearms, .lats], secondary: [.traps],
                 equipment: [.pullupBar], difficulty: 1)
    ]

    // MARK: Core

    static let core: [Exercise] = [
        Exercise(id: "plank", name: "Plank", scheme: "3 x 30-45s", sets: 3,
                 howTo: "Rest on your forearms and toes with your body in one straight line from head to heels. Hold and breathe normally.",
                 cue: "Squeeze your glutes so your hips don't sag or pike up.",
                 tracksWeight: false, modality: .hold(low: 30, high: 45),
                 pattern: .core, primary: [.abs], secondary: [.obliques, .frontDelts],
                 equipment: [.bodyweight], difficulty: 1),
        Exercise(id: "hollow_hold", name: "Hollow Hold", scheme: "3 x 20-30s", sets: 3,
                 howTo: "Lie on your back, press your lower back into the floor, and lift your shoulders and legs a few inches off the ground. Hold that banana shape.",
                 cue: "If your lower back lifts off the floor, raise your legs higher.",
                 tracksWeight: false, modality: .hold(low: 20, high: 30),
                 pattern: .core, primary: [.abs], secondary: [.obliques],
                 equipment: [.bodyweight], difficulty: 2),
        Exercise(id: "side_plank", name: "Side Plank", scheme: "3 x 25s / side", sets: 3,
                 howTo: "Lie on your side propped on one forearm, feet stacked. Lift your hips so your body is a straight line, and hold.",
                 cue: "Push the floor away — don't let your bottom shoulder sink.",
                 tracksWeight: false, modality: .hold(low: 20, high: 35),
                 pattern: .core, primary: [.obliques], secondary: [.abs, .glutes],
                 equipment: [.bodyweight], stress: [.shoulders], difficulty: 1),
        Exercise(id: "dead_bug", name: "Dead Bug", scheme: "3 x 10 / side", sets: 3,
                 howTo: "Lie on your back with arms up and knees over hips. Slowly lower one arm and the opposite leg, then bring them back and switch.",
                 cue: "Lower back stays glued to the floor the whole time.",
                 tracksWeight: false, pattern: .core, primary: [.abs], secondary: [.obliques],
                 equipment: [.bodyweight], difficulty: 1),
        Exercise(id: "bird_dog", name: "Bird Dog", scheme: "3 x 10 / side", sets: 3,
                 howTo: "On hands and knees, reach one arm forward and the opposite leg back until both are level with your body. Hold a beat, then switch.",
                 cue: "Move slowly — the point is not wobbling.",
                 tracksWeight: false, pattern: .core, primary: [.lowerBack, .abs], secondary: [.glutes],
                 equipment: [.bodyweight], difficulty: 1),
        Exercise(id: "farmer_carry", name: "Farmer's Carry", scheme: "3 x 40s", sets: 3,
                 howTo: "Pick up a heavy weight in each hand and walk. Stand tall, shoulders back, and just keep walking.",
                 cue: "Don't lean — walk like the weights aren't there.",
                 modality: .hold(low: 30, high: 60),
                 pattern: .carry, primary: [.forearms, .traps], secondary: [.abs, .obliques, .glutes],
                 equipment: [.dumbbells], difficulty: 1)
    ]

    // MARK: Conditioning

    static let conditioning: [Exercise] = [
        Exercise(id: "cond_cindy", name: "Scaled Cindy", scheme: "12 min AMRAP", sets: 1,
                 howTo: "For 12 minutes, keep repeating: 5 ring rows or jumping pull-ups, 10 knee push-ups, 15 air squats. Count how many full rounds you finish.",
                 cue: "Pick a pace you can hold for all 12 minutes — steady beats sprint-and-die.",
                 tracksWeight: false,
                 modality: .amrap(minutes: 12, movements: ["5 ring rows / jumping pull-ups", "10 knee push-ups", "15 air squats"]),
                 pattern: .conditioning, primary: [.quads, .chest, .lats], secondary: [.abs, .glutes, .triceps],
                 equipment: [.bodyweight], difficulty: 2),
        Exercise(id: "cond_cindy_long", name: "Scaled Cindy", scheme: "15 min AMRAP", sets: 1,
                 howTo: "Same as the 12 minute version but for 15: 5 ring rows or jumping pull-ups, 10 knee push-ups, 15 air squats, repeat.",
                 cue: "Aim to beat your last round count by at least one.",
                 tracksWeight: false,
                 modality: .amrap(minutes: 15, movements: ["5 ring rows / jumping pull-ups", "10 knee push-ups", "15 air squats"]),
                 pattern: .conditioning, primary: [.quads, .chest, .lats], secondary: [.abs, .glutes, .triceps],
                 equipment: [.bodyweight], difficulty: 2),
        Exercise(id: "cond_rounds", name: "Five Rounds", scheme: "5 rounds, 1 min rest", sets: 1,
                 howTo: "Each round is 10 goblet squats, 8 push-ups and a 20 second plank, then rest one full minute before the next round.",
                 cue: "Actually take the full rest — the rounds should stay fast.",
                 tracksWeight: false,
                 modality: .rounds(count: 5, movements: ["10 goblet squats", "8 push-ups", "20s plank"], restSeconds: 60),
                 pattern: .conditioning, primary: [.quads, .chest], secondary: [.abs, .glutes, .triceps],
                 equipment: [.dumbbells], difficulty: 2),
        Exercise(id: "cond_for_time", name: "Three Rounds For Time", scheme: "3 rounds, for time", sets: 1,
                 howTo: "As fast as you safely can: 15 air squats, 12 push-ups, 400m run. Three times through. Note your finish time.",
                 cue: "Break the push-ups up early so you never fully stall.",
                 tracksWeight: false,
                 modality: .forTime(rounds: 3, movements: ["15 air squats", "12 push-ups", "400m run"]),
                 pattern: .conditioning, primary: [.quads, .chest], secondary: [.calves, .abs, .glutes],
                 equipment: [.bodyweight], difficulty: 3),
        Exercise(id: "cond_emom", name: "Ten Minute Grinder", scheme: "10 rounds", sets: 1,
                 howTo: "Ten rounds of 8 kettlebell swings, 6 push-ups and 20 seconds rest. Short, sharp and over quickly.",
                 cue: "If a round takes longer than 40 seconds, cut the reps.",
                 tracksWeight: false,
                 modality: .rounds(count: 10, movements: ["8 kettlebell swings", "6 push-ups"], restSeconds: 20),
                 pattern: .conditioning, primary: [.glutes, .hamstrings, .chest], secondary: [.abs, .traps],
                 equipment: [.kettlebell], difficulty: 2)
    ]

    // MARK: Cardio

    static let cardioWork: [Exercise] = [
        Exercise(id: "trail_cardio", name: "Trail Cardio", scheme: "30-40 min easy", sets: 1,
                 howTo: "Head out on a trail or hilly route and keep an easy pace for 30–40 minutes. Walking the steep parts is completely fine.",
                 cue: "Easy means you could still hold a conversation the whole time.",
                 tracksWeight: false, modality: .trail(lowMin: 30, highMin: 40),
                 pattern: .cardio, primary: [.quads, .hamstrings, .calves], secondary: [.glutes],
                 equipment: [.bodyweight], difficulty: 1),
        Exercise(id: "easy_walk", name: "Easy Walk", scheme: "20-30 min", sets: 1,
                 howTo: "A relaxed walk. Outside if you can, at whatever pace feels comfortable.",
                 cue: "This is recovery, not training. Keep it genuinely easy.",
                 tracksWeight: false, modality: .trail(lowMin: 20, highMin: 30),
                 pattern: .cardio, primary: [.calves], secondary: [.quads, .hamstrings],
                 equipment: [.bodyweight], difficulty: 1),
        Exercise(id: "long_trail", name: "Long Trail Session", scheme: "45-60 min", sets: 1,
                 howTo: "A relaxed 45–60 minute hike or jog. Steady effort, nothing heroic.",
                 cue: "If you're sore or tired, cut it short — that still counts.",
                 tracksWeight: false, modality: .trail(lowMin: 45, highMin: 60),
                 pattern: .cardio, primary: [.quads, .hamstrings, .calves], secondary: [.glutes],
                 equipment: [.bodyweight], difficulty: 2)
    ]

    // MARK: Mobility

    static let mobility: [Exercise] = [
        Exercise(id: "hip_flow", name: "Hip Opener Flow", scheme: "3 x 45s", sets: 3,
                 howTo: "Move slowly between a deep lunge, a hip stretch with your back knee down, and a hamstring reach. Breathe in each position.",
                 cue: "Never push into sharp pain — this should feel like relief.",
                 tracksWeight: false, modality: .hold(low: 40, high: 60),
                 pattern: .mobility, primary: [.glutes, .hamstrings], secondary: [.quads, .lowerBack],
                 equipment: [.bodyweight], difficulty: 1),
        Exercise(id: "shoulder_flow", name: "Shoulder Opener", scheme: "3 x 45s", sets: 3,
                 howTo: "Slow arm circles, then reach one arm across your chest and hold, then clasp your hands behind your back and lift.",
                 cue: "Small ranges done well beat big ranges forced.",
                 tracksWeight: false, modality: .hold(low: 40, high: 60),
                 pattern: .mobility, primary: [.frontDelts, .rearDelts], secondary: [.traps, .chest],
                 equipment: [.bodyweight], difficulty: 1),
        Exercise(id: "spine_flow", name: "Cat-Cow and Twists", scheme: "3 x 60s", sets: 3,
                 howTo: "On hands and knees, alternate arching and rounding your back. Then sit and twist gently side to side.",
                 cue: "Move with your breath, slower than feels natural.",
                 tracksWeight: false, modality: .hold(low: 45, high: 75),
                 pattern: .mobility, primary: [.lowerBack, .abs], secondary: [.obliques],
                 equipment: [.bodyweight], difficulty: 1)
    ]
}
