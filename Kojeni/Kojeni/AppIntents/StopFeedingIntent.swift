import AppIntents
import ActivityKit
import SwiftData
import Foundation
import OSLog

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

        // End Live Activity
        if let activity = Activity<FeedingAttributes>.activities.first {
            await activity.end(nil, dismissalPolicy: .immediate)
            log.info("LA ended")
        }

        return .result()
    }
}
