import Foundation
import UserNotifications

/// Daily verse reminder. iOS can't run code at an alarm time, so the next 30 days are scheduled
/// up front, each with that day's verse, and refreshed whenever the app becomes active.
enum Reminders {
    static let prefix = "daily-verse-"
    static let daysAhead = 30

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(enabled: Bool, hour: Int, minute: Int, translation: Translation) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard enabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let cal = Calendar.current
        let now = Date()
        for offset in 0..<daysAhead {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            var c = cal.dateComponents([.year, .month, .day], from: day)
            c.hour = hour
            c.minute = minute
            guard let fire = cal.date(from: c), fire > now else { continue }
            let content = content(for: day, translation: translation)
            let trigger = UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
            let id = prefix + "\(c.year!)-\(c.month!)-\(c.day!)"
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    static func sendTest(translation: Translation) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "test-reminder", content: content(for: Date(), translation: translation), trigger: trigger))
    }

    private static func content(for day: Date, translation: Translation) -> UNMutableNotificationContent {
        let ref = VerseOfDay.reference(for: day)
        let label = ref.label(translation.bookName(ref.book))
        let text = BibleStore.shared.verse(translation.id, book: ref.book.number, chapter: ref.chapter, verse: ref.verse ?? 1)?.text ?? ""
        let content = UNMutableNotificationContent()
        content.title = "Verse of the day · \(label)"
        content.body = text
        content.sound = .default
        return content
    }
}

/// Shows reminders as banners even while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
