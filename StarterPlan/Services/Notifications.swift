import Foundation
import UserNotifications

final class Notifications {
    static let shared = Notifications()
    private init() {}

    private let dailyID = "starterplan.daily"
    private let riskID = "starterplan.streakRisk"

    func requestAndSchedule(store: Store) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { self.schedule(store: store) }
        }
    }

    func refresh(store: Store) {
        guard store.profile.notificationsEnabled else { cancelAll(); return }
        UNUserNotificationCenter.current().getNotificationSettings { s in
            guard s.authorizationStatus == .authorized || s.authorizationStatus == .provisional else { return }
            DispatchQueue.main.async { self.schedule(store: store) }
        }
    }

    private func schedule(store: Store) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyID, riskID])
        guard !store.isPlanFinished else { return }

        let day = Plan.day(at: store.currentDayIndex)

        // Morning nudge — 9:00
        let daily = UNMutableNotificationContent()
        daily.title = day.kind.isRest ? "Rest day — tap to bank it 😴" : "\(day.kind.title) is waiting"
        daily.body = day.kind.isRest
            ? "Log your rest day and keep the streak alive."
            : "Week \(day.week), \(day.weekdayName). \(day.totalSets) sets and you're done."
        daily.sound = .default
        center.add(UNNotificationRequest(identifier: dailyID,
                                         content: daily,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 9, minute: 0), repeats: true)))

        // Streak-at-risk — 19:30
        let risk = UNMutableNotificationContent()
        risk.title = "Don't break your streak 🔥"
        risk.body = store.profile.streak > 1
            ? "\(store.profile.streak) days in a row. A few minutes is all it takes."
            : "One workout today and the streak starts climbing."
        risk.sound = .default
        center.add(UNNotificationRequest(identifier: riskID,
                                         content: risk,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 19, minute: 30), repeats: true)))
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
