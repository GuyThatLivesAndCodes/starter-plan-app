import Foundation
import SwiftData
import Observation
import SwiftUI

// MARK: - Persistence

@Model
final class Profile {
    var xp: Int = 0
    var streak: Int = 0
    var bestStreak: Int = 0
    var lastCompletedDay: Date?
    var soundEnabled: Bool = true
    var notificationsEnabled: Bool = true
    var startedOn: Date = Date()

    // Body profile — collected at first launch, editable in Settings.
    var onboarded: Bool = false
    var age: Int = 0
    var heightIn: Double = 0          // total inches
    var bodyWeightLb: Double = 0
    var sexRaw: String = "unspecified"
    var experienceRaw: String = "beginner"

    // Economy
    var coins: Int = 0
    var unlockedGamesRaw: String = "tap_rush"     // comma separated game ids

    var sex: BodySex {
        get { BodySex(rawValue: sexRaw) ?? .unspecified }
        set { sexRaw = newValue.rawValue }
    }
    var experience: Experience {
        get { Experience(rawValue: experienceRaw) ?? .beginner }
        set { experienceRaw = newValue.rawValue }
    }
    var unlockedGames: Set<String> {
        get { Set(unlockedGamesRaw.split(separator: ",").map(String.init)) }
        set { unlockedGamesRaw = newValue.sorted().joined(separator: ",") }
    }
    var hasBody: Bool { age > 0 && heightIn > 0 && bodyWeightLb > 0 }
    var bmi: Double {
        guard heightIn > 0 else { return 0 }
        return 703 * bodyWeightLb / (heightIn * heightIn)
    }

    init() {}
}

enum BodySex: String, CaseIterable, Identifiable {
    case male, female, unspecified
    var id: String { rawValue }
    var label: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .unspecified: return "Rather not say"
        }
    }
}

enum Experience: String, CaseIterable, Identifiable {
    case beginner, some, experienced
    var id: String { rawValue }
    var label: String {
        switch self {
        case .beginner: return "Brand new"
        case .some: return "Some lifting"
        case .experienced: return "Experienced"
        }
    }
    var blurb: String {
        switch self {
        case .beginner: return "Never trained, or coming back after a long break"
        case .some: return "On and off for a few months"
        case .experienced: return "Lifting consistently for a year or more"
        }
    }
}

/// How a single set felt. Drives every weight adjustment the coach makes.
enum Effort: Int, CaseIterable, Identifiable, Codable {
    case easy = 0, good = 1, hard = 2, failed = 3
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .easy: return "Easy"
        case .good: return "Just right"
        case .hard: return "Hard"
        case .failed: return "Couldn't finish"
        }
    }
    var icon: String {
        switch self {
        case .easy: return "wind"
        case .good: return "checkmark.circle.fill"
        case .hard: return "flame.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

@Model
final class DayLog {
    @Attribute(.unique) var dayIndex: Int
    var completedOn: Date
    var xpEarned: Int

    init(dayIndex: Int, completedOn: Date = .now, xpEarned: Int) {
        self.dayIndex = dayIndex
        self.completedOn = completedOn
        self.xpEarned = xpEarned
    }
}

@Model
final class ExerciseState {
    @Attribute(.unique) var exerciseID: String
    var lastWeight: Double
    var fullSessionStreak: Int      // consecutive sessions where every set was hit
    var pendingBump: Bool           // show "+5-10 lb" nudge
    var cardioLowMin: Int = 0       // coach-adjusted trail window
    var cardioHighMin: Int = 0
    var holdTarget: Int = 0         // coach-adjusted hold seconds
    var bestRounds: Int = 0         // AMRAP personal best

    init(exerciseID: String, lastWeight: Double = 0, fullSessionStreak: Int = 0, pendingBump: Bool = false) {
        self.exerciseID = exerciseID
        self.lastWeight = lastWeight
        self.fullSessionStreak = fullSessionStreak
        self.pendingBump = pendingBump
    }
}

@Model
final class SessionEntry {
    var dayIndex: Int
    var exerciseID: String
    var weight: Double
    var setsCompleted: Int
    var date: Date

    init(dayIndex: Int, exerciseID: String, weight: Double, setsCompleted: Int, date: Date = .now) {
        self.dayIndex = dayIndex
        self.exerciseID = exerciseID
        self.weight = weight
        self.setsCompleted = setsCompleted
        self.date = date
    }
}

/// One completed (or attempted) set — the raw material the coach reads.
@Model
final class SetRecord {
    var dayIndex: Int
    var exerciseID: String
    var setNumber: Int
    var weight: Double
    var effortRaw: Int
    var restSeconds: Int        // actual rest taken after this set
    var restTarget: Int         // rest the app asked for
    var heldSeconds: Int = 0    // for holds — shown to the user, not used to grade them
    var reps: Int = 0           // logged reps when they differ from the target
    var date: Date

    var effort: Effort { Effort(rawValue: effortRaw) ?? .good }
    var restOvertime: Int { max(0, restSeconds - restTarget) }

    init(dayIndex: Int, exerciseID: String, setNumber: Int, weight: Double,
         effort: Effort, restSeconds: Int = 0, restTarget: Int = 0, date: Date = .now) {
        self.dayIndex = dayIndex
        self.exerciseID = exerciseID
        self.setNumber = setNumber
        self.weight = weight
        self.effortRaw = effort.rawValue
        self.restSeconds = restSeconds
        self.restTarget = restTarget
        self.date = date
    }
}

/// A completed trail session. Splits are stored as one meters-per-minute value
/// per elapsed minute, which is enough to see where someone faded or bailed.
@Model
final class CardioSession {
    var dayIndex: Int
    var exerciseID: String
    var date: Date
    var seconds: Int
    var meters: Double
    var targetLowMin: Int
    var targetHighMin: Int
    var usedLocation: Bool
    var autoPauses: Int
    var pausedSeconds: Int
    var splitsRaw: String        // comma separated meters-per-minute
    var effortRaw: Int

    var effort: Effort { Effort(rawValue: effortRaw) ?? .good }
    var minutes: Double { Double(seconds) / 60 }
    var splits: [Double] { splitsRaw.split(separator: ",").compactMap { Double($0) } }
    var miles: Double { meters / 1609.34 }

    /// Seconds per mile. Zero when there's no distance (untracked session).
    var pace: Double { miles > 0 ? Double(seconds) / miles : 0 }

    /// Negative means they sped up in the back half, positive means they faded.
    var fadePercent: Double {
        let s = splits.filter { $0 > 0 }
        guard s.count >= 4 else { return 0 }
        let half = s.count / 2
        let first = s.prefix(half).reduce(0, +) / Double(half)
        let second = s.suffix(s.count - half).reduce(0, +) / Double(s.count - half)
        guard first > 0 else { return 0 }
        return (first - second) / first * 100
    }

    var finishedShort: Bool { minutes < Double(targetLowMin) - 0.5 }
    var finishedLong: Bool { minutes > Double(targetHighMin) + 0.5 }

    init(dayIndex: Int, exerciseID: String, seconds: Int, meters: Double,
         targetLowMin: Int, targetHighMin: Int, usedLocation: Bool,
         autoPauses: Int, pausedSeconds: Int, splits: [Double], effort: Effort, date: Date = .now) {
        self.dayIndex = dayIndex
        self.exerciseID = exerciseID
        self.date = date
        self.seconds = seconds
        self.meters = meters
        self.targetLowMin = targetLowMin
        self.targetHighMin = targetHighMin
        self.usedLocation = usedLocation
        self.autoPauses = autoPauses
        self.pausedSeconds = pausedSeconds
        self.splitsRaw = splits.map { String(format: "%.0f", $0) }.joined(separator: ",")
        self.effortRaw = effort.rawValue
    }
}

/// AMRAP / rounds / for-time result.
@Model
final class ConditioningResult {
    var dayIndex: Int
    var exerciseID: String
    var date: Date
    var rounds: Int
    var partialReps: Int
    var seconds: Int
    var roundSplitsRaw: String    // comma separated seconds per round
    var effortRaw: Int

    var effort: Effort { Effort(rawValue: effortRaw) ?? .good }
    var roundSplits: [Int] { roundSplitsRaw.split(separator: ",").compactMap { Int($0) } }

    init(dayIndex: Int, exerciseID: String, rounds: Int, partialReps: Int,
         seconds: Int, roundSplits: [Int], effort: Effort, date: Date = .now) {
        self.dayIndex = dayIndex
        self.exerciseID = exerciseID
        self.date = date
        self.rounds = rounds
        self.partialReps = partialReps
        self.seconds = seconds
        self.roundSplitsRaw = roundSplits.map(String.init).joined(separator: ",")
        self.effortRaw = effort.rawValue
    }
}

/// A plan day done ahead of schedule. Worth half credit and, deliberately, it
/// does not move the plan forward — you can't bank a week in one afternoon.
@Model
final class BonusSession {
    var dayIndex: Int
    var date: Date
    var xpEarned: Int

    init(dayIndex: Int, date: Date = .now, xpEarned: Int) {
        self.dayIndex = dayIndex
        self.date = date
        self.xpEarned = xpEarned
    }
}

// MARK: - Store

@Observable
final class Store {
    let context: ModelContext
    private(set) var profile: Profile
    private(set) var completed: Set<Int> = []
    private(set) var logs: [DayLog] = []
    private(set) var bonuses: [BonusSession] = []

    init(context: ModelContext) {
        self.context = context
        let existing = (try? context.fetch(FetchDescriptor<Profile>()))?.first
        if let existing {
            profile = existing
        } else {
            let p = Profile()
            context.insert(p)
            profile = p
        }
        reload()
    }

    func reload() {
        logs = (try? context.fetch(FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\.dayIndex)]))) ?? []
        bonuses = (try? context.fetch(FetchDescriptor<BonusSession>(sortBy: [SortDescriptor(\.date)]))) ?? []
        completed = Set(logs.map(\.dayIndex))
        recomputeStreak()
    }

    // The furthest day the user is allowed to open: first uncompleted day.
    var currentDayIndex: Int {
        for i in 0..<Plan.days.count where !completed.contains(i) { return i }
        return Plan.days.count - 1
    }

    var isPlanFinished: Bool { completed.count == Plan.days.count }

    func isComplete(_ index: Int) -> Bool { completed.contains(index) }

    // MARK: Sliding schedule
    //
    // The plan is a queue, not a calendar. Whatever is next is always dated
    // today; everything behind it slides one day per day. Miss a day and that
    // session simply moves onto the next day rather than being lost, and the
    // days after it move with it.

    /// The session the user is meant to do today.
    var todaysIndex: Int { currentDayIndex }

    /// True once the user has completed the scheduled session today.
    var todaysSessionDone: Bool {
        let cal = Calendar.current
        return logs.contains { cal.isDateInToday($0.completedOn) }
    }

    func scheduledDate(for index: Int) -> Date {
        let cal = Calendar.current
        if let log = logs.first(where: { $0.dayIndex == index }) { return log.completedOn }
        let offset = index - currentDayIndex
        return cal.date(byAdding: .day, value: max(0, offset), to: cal.startOfDay(for: .now)) ?? .now
    }

    /// A session done ahead of its slot: allowed, half credit, doesn't advance the plan.
    func isBonusDay(_ index: Int) -> Bool { index > currentDayIndex }

    /// Today's session is always available. Anything further ahead only opens up
    /// once today's is actually done.
    func isUnlocked(_ index: Int) -> Bool {
        if index <= currentDayIndex { return true }
        return todaysSessionDone
    }

    func bonusCount(_ index: Int) -> Int { bonuses.filter { $0.dayIndex == index }.count }

    /// Short label for the node on the path.
    func dateLabel(for index: Int) -> String {
        let cal = Calendar.current
        let date = scheduledDate(for: index)
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: date)).day ?? 0
        if days > 0 && days < 7 { return date.formatted(.dateTime.weekday(.abbreviated)) }
        return date.formatted(.dateTime.weekday(.abbreviated).day())
    }

    func weekProgress(_ week: Int) -> Double {
        let range = ((week - 1) * 7)..<(week * 7)
        let done = range.filter { completed.contains($0) }.count
        return Double(done) / 7.0
    }

    var currentWeek: Int { min(currentDayIndex / 7 + 1, 4) }

    // MARK: Exercise state

    func state(for exerciseID: String) -> ExerciseState {
        let d = FetchDescriptor<ExerciseState>(predicate: #Predicate { $0.exerciseID == exerciseID })
        if let found = (try? context.fetch(d))?.first { return found }
        let fresh = ExerciseState(exerciseID: exerciseID)
        context.insert(fresh)
        return fresh
    }

    func setWeight(_ weight: Double, for exerciseID: String) {
        state(for: exerciseID).lastWeight = max(0, weight)
        try? context.save()
    }

    // MARK: Completion

    /// Records a finished workout. `results` maps exercise id -> (sets completed, weight used).
    @discardableResult
    func completeDay(_ day: WorkoutDay, results: [String: (sets: Int, weight: Double)], bonus: Bool = false) -> Int {
        guard !completed.contains(day.index) else { return 0 }

        var xp = 0
        for ex in day.exercises {
            let r = results[ex.id] ?? (sets: ex.sets, weight: 0)
            xp += r.sets * 10
            let st = state(for: ex.id)
            st.lastWeight = r.weight
            if r.sets >= ex.sets {
                st.fullSessionStreak += 1
                st.pendingBump = ex.tracksWeight && st.fullSessionStreak >= 2
            } else {
                st.fullSessionStreak = 0
                st.pendingBump = false
            }
            context.insert(SessionEntry(dayIndex: day.index, exerciseID: ex.id, weight: r.weight, setsCompleted: r.sets))
        }
        if day.kind.isRest { xp = 20 }

        // Effort bonus — harder honest work pays more than coasting.
        for r in records(forDay: day.index) {
            switch r.effort {
            case .easy: xp += 1
            case .good: xp += 3
            case .hard: xp += 5
            case .failed: xp += 2
            }
            if r.restOvertime == 0 { xp += 1 }
        }

        if bonus {
            // Half credit, and the queue does not move — this session will still
            // be waiting when its real slot comes around.
            xp = max(1, xp / 2)
            context.insert(BonusSession(dayIndex: day.index, xpEarned: xp))
        } else {
            context.insert(DayLog(dayIndex: day.index, xpEarned: xp))
        }
        profile.xp += xp
        profile.lastCompletedDay = .now
        try? context.save()
        reload()
        return xp
    }

    func acceptBump(for exerciseID: String, increment: Double) {
        let st = state(for: exerciseID)
        st.lastWeight += increment
        st.pendingBump = false
        st.fullSessionStreak = 0
        try? context.save()
    }

    // MARK: Set records

    func save(_ record: SetRecord) {
        context.insert(record)
        try? context.save()
    }

    func records(exerciseID: String) -> [SetRecord] {
        let d = FetchDescriptor<SetRecord>(
            predicate: #Predicate { $0.exerciseID == exerciseID },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(d)) ?? []
    }

    func allRecords() -> [SetRecord] {
        (try? context.fetch(FetchDescriptor<SetRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
    }

    func records(forDay index: Int) -> [SetRecord] {
        let d = FetchDescriptor<SetRecord>(predicate: #Predicate { $0.dayIndex == index },
                                           sortBy: [SortDescriptor(\.setNumber)])
        return (try? context.fetch(d)) ?? []
    }

    // MARK: Economy

    /// Coins are earned for effort, not just attendance.
    @discardableResult
    func awardCoins(for effort: Effort, restOvertime: Int) -> Int {
        var c: Int
        switch effort {
        case .easy: c = 2
        case .good: c = 4
        case .hard: c = 6
        case .failed: c = 3      // showing up for a set you can't finish still counts
        }
        if restOvertime <= 0 { c += 1 }          // stuck to the prescribed rest
        profile.coins += c
        try? context.save()
        return c
    }

    func awardBonus(_ amount: Int) {
        profile.coins += amount
        try? context.save()
    }

    func isUnlocked(game id: String) -> Bool { profile.unlockedGames.contains(id) }

    @discardableResult
    func unlock(game id: String, cost: Int) -> Bool {
        guard profile.coins >= cost, !isUnlocked(game: id) else { return false }
        profile.coins -= cost
        var g = profile.unlockedGames
        g.insert(id)
        profile.unlockedGames = g
        try? context.save()
        return true
    }

    func save(_ session: CardioSession) {
        context.insert(session)
        try? context.save()
    }

    func save(_ result: ConditioningResult) {
        context.insert(result)
        try? context.save()
    }

    func cardioSessions(exerciseID: String) -> [CardioSession] {
        let d = FetchDescriptor<CardioSession>(
            predicate: #Predicate { $0.exerciseID == exerciseID },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(d)) ?? []
    }

    func conditioningResults(exerciseID: String) -> [ConditioningResult] {
        let d = FetchDescriptor<ConditioningResult>(
            predicate: #Predicate { $0.exerciseID == exerciseID },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(d)) ?? []
    }

    func cardioSessions(forDay index: Int) -> [CardioSession] {
        let d = FetchDescriptor<CardioSession>(predicate: #Predicate { $0.dayIndex == index })
        return (try? context.fetch(d)) ?? []
    }

    func conditioningResults(forDay index: Int) -> [ConditioningResult] {
        let d = FetchDescriptor<ConditioningResult>(predicate: #Predicate { $0.dayIndex == index })
        return (try? context.fetch(d)) ?? []
    }

    func saveBody(age: Int, heightIn: Double, weightLb: Double, sex: BodySex, experience: Experience) {
        profile.age = age
        profile.heightIn = heightIn
        profile.bodyWeightLb = weightLb
        profile.sex = sex
        profile.experience = experience
        profile.onboarded = true
        try? context.save()
    }

    func entries(forDay index: Int) -> [SessionEntry] {
        let d = FetchDescriptor<SessionEntry>(predicate: #Predicate { $0.dayIndex == index })
        return (try? context.fetch(d)) ?? []
    }

    func log(forDate date: Date) -> DayLog? {
        let cal = Calendar.current
        return logs.first { cal.isDate($0.completedOn, inSameDayAs: date) }
    }

    // MARK: Streak

    private func recomputeStreak() {
        let cal = Calendar.current
        let active = logs.map(\.completedOn) + bonuses.map(\.date)
        let days = Set(active.map { cal.startOfDay(for: $0) }).sorted(by: >)
        guard let latest = days.first else { profile.streak = 0; return }

        let today = cal.startOfDay(for: .now)
        let gap = cal.dateComponents([.day], from: latest, to: today).day ?? 0
        guard gap <= 1 else { profile.streak = 0; return }

        var streak = 1
        var cursor = latest
        for d in days.dropFirst() {
            if cal.dateComponents([.day], from: d, to: cursor).day == 1 {
                streak += 1
                cursor = d
            } else { break }
        }
        profile.streak = streak
        profile.bestStreak = max(profile.bestStreak, streak)
    }

    var streakAtRisk: Bool {
        guard profile.streak > 0 else { return false }
        return !todaysSessionDone
    }

    // MARK: Settings / reset

    func toggleSound(_ on: Bool) { profile.soundEnabled = on; try? context.save() }

    func setNotifications(_ on: Bool) {
        profile.notificationsEnabled = on
        try? context.save()
        if on { Notifications.shared.requestAndSchedule(store: self) }
        else { Notifications.shared.cancelAll() }
    }

    func resetPlan() {
        for l in logs { context.delete(l) }
        for e in (try? context.fetch(FetchDescriptor<SessionEntry>())) ?? [] { context.delete(e) }
        for r in (try? context.fetch(FetchDescriptor<SetRecord>())) ?? [] { context.delete(r) }
        for c in (try? context.fetch(FetchDescriptor<CardioSession>())) ?? [] { context.delete(c) }
        for c in (try? context.fetch(FetchDescriptor<ConditioningResult>())) ?? [] { context.delete(c) }
        for b in (try? context.fetch(FetchDescriptor<BonusSession>())) ?? [] { context.delete(b) }
        for s in (try? context.fetch(FetchDescriptor<ExerciseState>())) ?? [] {
            s.cardioLowMin = 0; s.cardioHighMin = 0; s.holdTarget = 0; s.bestRounds = 0
        }
        for s in (try? context.fetch(FetchDescriptor<ExerciseState>())) ?? [] {
            s.fullSessionStreak = 0
            s.pendingBump = false
        }
        profile.xp = 0
        profile.streak = 0
        profile.coins = 0
        profile.lastCompletedDay = nil
        profile.startedOn = .now
        try? context.save()
        reload()
    }
}
