import Foundation
import UserNotifications

/// Four nudges a day, and none of them fire once the day's session is done.
///
/// iOS can't ask a question at delivery time, so instead of repeating triggers
/// this schedules concrete dated notifications a week out and rebuilds the whole
/// set whenever the picture changes — on launch, on foreground, and the moment a
/// session is logged. Finishing today's workout wipes the rest of today's nudges.
final class Notifications {
    static let shared = Notifications()
    private init() {}

    private struct Slot {
        let hour: Int
        let minute: Int
        let title: (String) -> String
        let body: (Store, WorkoutDay) -> String
    }

    private let slots: [Slot] = [
        Slot(hour: 10, minute: 30,
             title: { "\($0) is on for today" },
             body: { _, day in
                 day.kind.isRest
                     ? "Rest day. Log it whenever and the streak keeps rolling."
                     : "\(day.totalSets > 0 ? "\(day.totalSets) sets" : "One session") standing between you and done."
             }),
        Slot(hour: 12, minute: 30,
             title: { _ in "Lunchtime check-in 🍽️" },
             body: { store, day in
                 store.profile.streak > 0
                     ? "\(store.profile.streak) day streak still needs \(day.kind.title.lowercased())."
                     : "\(day.kind.title) is still waiting. Twenty minutes is enough."
             }),
        Slot(hour: 15, minute: 30,
             title: { _ in "Still time for it" },
             body: { _, day in
                 day.kind.isRest
                     ? "Two taps to bank the rest day."
                     : "\(day.kind.title) hasn't happened yet. Get it done before the evening slump."
             }),
        Slot(hour: 19, minute: 30,
             title: { _ in "Don't break your streak 🔥" },
             body: { store, day in
                 store.profile.streak > 1
                     ? "\(store.profile.streak) days in a row. \(day.kind.title) is all that's left today."
                     : "One session tonight and the streak starts climbing."
             })
    ]

    private let prefix = "starterplan.nudge."

    // MARK: Public

    func requestAndSchedule(store: Store) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { self.schedule(store: store) }
        }
    }

    /// Safe to call as often as you like — it always rebuilds from scratch.
    func refresh(store: Store) {
        guard store.profile.notificationsEnabled else { cancelAll(); return }
        UNUserNotificationCenter.current().getNotificationSettings { s in
            switch s.authorizationStatus {
            case .authorized, .provisional:
                DispatchQueue.main.async { self.schedule(store: store) }
            case .notDetermined:
                self.requestAndSchedule(store: store)
            default:
                break
            }
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: Scheduling

    private func schedule(store: Store) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard !store.isPlanFinished else { return }

        let cal = Calendar.current
        let now = Date()
        let head = store.currentDayIndex
        let doneToday = store.todaysSessionDone

        for offset in 0..<7 {
            // Today's nudges are pointless once the session is logged.
            if offset == 0 && doneToday { continue }

            guard let dayDate = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) else { continue }

            // If they stay on plan it's head + offset; if they miss a day the app
            // rebuilds this list on next launch, so a slip self-corrects.
            let index = min(head + offset, Plan.days.count - 1)
            let day = Plan.day(at: index)

            for slot in slots {
                guard let fire = cal.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: dayDate),
                      fire > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = slot.title(day.kind.title)
                content.body = slot.body(store, day)
                content.sound = .default            // always audible
                content.interruptionLevel = .timeSensitive
                content.threadIdentifier = "starterplan"

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let request = UNNotificationRequest(
                    identifier: "\(prefix)\(offset).\(slot.hour)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                center.add(request)
            }
        }
    }
}
