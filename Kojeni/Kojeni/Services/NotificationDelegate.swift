import Foundation
import UserNotifications
import OSLog

/// Routuje notifikace akce na callback closures.
/// `UNUserNotificationCenterDelegate` conformance umožňuje zachytit
/// tapnutí v notification — runtime ho zaregistruje `KojeniApp` (Task 5).
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    private let log = Logger(subsystem: "cz.zapletal.kojeni", category: "NotificationDelegate")
    private let onFeedingNow: @MainActor () -> Void
    private let onSnooze: @MainActor (Int) -> Void

    init(
        onFeedingNow: @escaping @MainActor () -> Void,
        onSnooze: @escaping @MainActor (Int) -> Void
    ) {
        self.onFeedingNow = onFeedingNow
        self.onSnooze = onSnooze
        super.init()
    }

    /// Test-friendly entry point — production code ji nezvolí přímo,
    /// jen přes UNUserNotificationCenterDelegate metodu níže.
    func handleAction(identifier: String) async {
        switch identifier {
        case ReminderScheduler.feedingNowActionID:
            log.info("Action: feeding-now")
            onFeedingNow()
        case ReminderScheduler.snooze15ActionID:
            log.info("Action: snooze-15")
            onSnooze(15)
        case ReminderScheduler.snooze30ActionID:
            log.info("Action: snooze-30")
            onSnooze(30)
        default:
            log.warning("Unknown action: \(identifier)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        Task { @MainActor in
            await handleAction(identifier: actionID)
            completionHandler()
        }
    }

    /// Foreground delivery — když app běží a notifikace dorazí.
    /// Zobrazíme ji jako banner, ne potichu spolknout.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
