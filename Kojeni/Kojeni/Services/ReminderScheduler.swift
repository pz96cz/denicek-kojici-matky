import Foundation
import UserNotifications
import OSLog

/// Protokol pro mockování `UNUserNotificationCenter` v unit testech.
/// Production `UNUserNotificationCenter.current()` conformance je dole v tomto souboru.
@MainActor
protocol NotificationCenterAPI {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func notificationSettings() async -> UNNotificationSettings
}

extension UNUserNotificationCenter: NotificationCenterAPI {}

@MainActor
@Observable
final class ReminderScheduler {

    @ObservationIgnored
    private let log = Logger(subsystem: "cz.zapletal.kojeni", category: "Reminder")

    @ObservationIgnored
    private let center: NotificationCenterAPI

    /// Stabilní identifier — vždy max 1 pending feeding reminder.
    static let notificationIdentifier = "feeding-reminder"

    /// Identifier UNNotificationCategory s 3 akcemi.
    static let categoryIdentifier = "feeding-reminder-category"

    /// Action identifiers — match s `NotificationDelegate` (Task 4).
    static let feedingNowActionID = "feeding-now-action"
    static let snooze15ActionID = "snooze-15-action"
    static let snooze30ActionID = "snooze-30-action"

    init(center: NotificationCenterAPI = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// Vyžádá permission od uživatele, registruje category s akcemi.
    /// Returns `true` pokud granted, `false` pokud denied.
    @discardableResult
    func requestAuthorization() async throws -> Bool {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        registerCategory()
        log.info("Authorization request: granted=\(granted)")
        return granted
    }

    /// Cache-friendly check, ne přes requestAuthorization aby se uživateli
    /// znovu neotevíral system dialog.
    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }

    private func registerCategory() {
        let feedingNow = UNNotificationAction(
            identifier: Self.feedingNowActionID,
            title: "Krmím teď",
            options: [.foreground]
        )
        let snooze15 = UNNotificationAction(
            identifier: Self.snooze15ActionID,
            title: "Odložit 15 min",
            options: []
        )
        let snooze30 = UNNotificationAction(
            identifier: Self.snooze30ActionID,
            title: "Odložit 30 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [feedingNow, snooze15, snooze30],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    /// Naplánuje notifikaci na `endedAt + intervalMinutes`.
    /// Pokud výsledek leží v minulosti, doručí ji okamžitě (trigger = nil).
    func scheduleAfter(endedAt: Date, intervalMinutes: Int) async throws {
        let triggerDate = endedAt.addingTimeInterval(TimeInterval(intervalMinutes * 60))
        let now = Date.now

        let content = UNMutableNotificationContent()
        content.title = "🤱 Čas na kojení"
        let hours = intervalMinutes / 60
        let mins = intervalMinutes % 60
        if hours > 0 && mins == 0 {
            content.body = "Od posledního krmení uběhly \(hours) h."
        } else if hours > 0 {
            content.body = "Od posledního krmení uběhly \(hours) h \(mins) min."
        } else {
            content.body = "Od posledního krmení uběhlo \(mins) min."
        }
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        let trigger: UNNotificationTrigger?
        if triggerDate > now {
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            trigger = nil   // immediate delivery
        }

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
        log.info("Scheduled reminder for \(triggerDate)")
    }

    /// Smaže pending feeding reminder. Idempotentní.
    func cancelPending() {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.notificationIdentifier]
        )
        log.debug("Cancelled pending reminder")
    }
}
