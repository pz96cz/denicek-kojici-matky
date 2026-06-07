import AppIntents
import ActivityKit
import SwiftData
import Foundation
import OSLog
import UserNotifications

/// Tlačítko „Stop" v Live Activity.
/// `openAppWhenRun = true` — otevře hlavní app. App si pak otevře PumpedMlSheet.
struct StopFeedingIntent: AppIntent {

    static var title: LocalizedStringResource = "Stop"
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        let log = Logger(subsystem: "cz.zapletal.kojeni", category: "StopFeedingIntent")

        let schema = Schema([
            FeedingSession.self,
            BreastChange.self,
            DiaperEvent.self,
            AppSettings.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(AppGroup.identifier)
        )
        let container = try ModelContainer(for: schema, configurations: [config])

        let endedAt = try await MainActor.run { () -> Date? in
            let context = ModelContext(container)
            let service = FeedingService(context: context)
            guard let ended = try service.endSession() else { return nil }
            return ended.endedAt
        }
        guard let endedAt else {
            log.warning("endSession returned nil — no active session, no-op")
            return .result()
        }

        // Předáme do main app, že má otevřít PumpedMlSheet pro tuto session.
        // SwiftData PersistentIdentifier nelze přes UserDefaults serializovat přímo,
        // ale uložíme dvojici (Bool flag, sessionEnd timestamp) — main app si
        // sezení dohledá podle endedAt v rozumném okně.
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        defaults?.set(true, forKey: "pendingPumpedMlSheet")
        defaults?.set(endedAt.timeIntervalSinceReferenceDate,
                      forKey: "pendingPumpedMlSheet.endedAt")
        log.info("Set pendingPumpedMlSheet flag")

        // Schedule next reminder podle aktuálních AppSettings
        // (ReminderScheduler není kompilován do widget procesu — přeplánujeme přímo
        // přes UNUserNotificationCenter; logika kopíruje ReminderScheduler.scheduleAfter)
        let interval = try await MainActor.run { () -> Int? in
            let context = ModelContext(container)
            let settings = try AppSettings.loadOrCreate(in: context)
            return settings.remindersEnabled ? settings.reminderIntervalMinutes : nil
        }
        if let interval {
            let triggerDate = endedAt.addingTimeInterval(TimeInterval(interval * 60))
            let content = UNMutableNotificationContent()
            content.title = "🤱 Čas na kojení"
            let hours = interval / 60
            let mins = interval % 60
            if hours > 0 && mins == 0 {
                content.body = "Od posledního krmení uběhly \(hours) h."
            } else if hours > 0 {
                content.body = "Od posledního krmení uběhly \(hours) h \(mins) min."
            } else {
                content.body = "Od posledního krmení uběhlo \(mins) min."
            }
            content.sound = .default
            content.categoryIdentifier = "feeding-reminder-category"

            let trigger: UNNotificationTrigger?
            if triggerDate > Date.now {
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: triggerDate
                )
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            } else {
                trigger = nil
            }
            let request = UNNotificationRequest(
                identifier: "feeding-reminder",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
            log.info("StopFeedingIntent: scheduled reminder for \(triggerDate)")
        }

        // End Live Activity
        if let activity = Activity<FeedingAttributes>.activities.first {
            await activity.end(nil, dismissalPolicy: .immediate)
            log.info("LA ended")
        }

        return .result()
    }
}
