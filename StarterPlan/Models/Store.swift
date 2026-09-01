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

    init() {}
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

// MARK: - Store

@Observable
final class Store {
    let context: ModelContext
    private(set) var profile: Profile
    private(set) var completed: Set<Int> = []
    private(set) var logs: [DayLog] = []

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
        completed = Set(logs.map(\.dayIndex))
        recomputeStreak()
    }

    // The furthest day the user is allowed to open: first uncompleted day.
    var currentDayIndex: Int {
        for i in 0..<Plan.days.count where !completed.contains(i) { return i }
        return Plan.days.count - 1
    }

    var isPlanFinished: Bool { completed.count == Plan.days.count }

    func isUnlocked(_ index: Int) -> Bool { index <= currentDayIndex }
    func isComplete(_ index: Int) -> Bool { completed.contains(index) }

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
    func completeDay(_ day: WorkoutDay, results: [String: (sets: Int, weight: Double)]) -> Int {
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

        context.insert(DayLog(dayIndex: day.index, xpEarned: xp))
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
        let days = Set(logs.map { cal.startOfDay(for: $0.completedOn) }).sorted(by: >)
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
        let cal = Calendar.current
        guard let last = profile.lastCompletedDay else { return true }
        return !cal.isDateInToday(last)
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
        for s in (try? context.fetch(FetchDescriptor<ExerciseState>())) ?? [] {
            s.fullSessionStreak = 0
            s.pendingBump = false
        }
        profile.xp = 0
        profile.streak = 0
        profile.lastCompletedDay = nil
        profile.startedOn = .now
        try? context.save()
        reload()
    }
}
