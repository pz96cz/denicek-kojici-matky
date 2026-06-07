import SwiftUI
import SwiftData
import UserNotifications

@main
struct KojeniApp: App {

    @State private var liveActivity = LiveActivityManager()
    @State private var reminderScheduler = ReminderScheduler()
    @State private var notificationDelegate: NotificationDelegate?

    let container: ModelContainer = {
        let schema = Schema([
            FeedingSession.self,
            BreastChange.self,
            DiaperEvent.self,
            AppSettings.self,
        ])
        // DIAG: App Group container vypnutý kvůli AltStore re-sign entitlement
        // limitaci na free Apple ID. Widget proces tím přestane sdílet store,
        // Live Activity tlačítka přestanou fungovat. Main app se spustí.
        // Po ověření že to byl důvod crashe → reactivate + vyřešit signing.
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer selhalo při startu: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(liveActivity)
                .environment(reminderScheduler)
                .task {
                    setupNotificationDelegate()
                }
        }
        .modelContainer(container)
    }

    /// Registrace delegate při startu app — drží reference v @State aby přežil.
    private func setupNotificationDelegate() {
        guard notificationDelegate == nil else { return }
        let delegate = NotificationDelegate(
            onFeedingNow: handleFeedingNowAction,
            onSnooze: handleSnoozeAction
        )
        UNUserNotificationCenter.current().delegate = delegate
        notificationDelegate = delegate
    }

    private func handleFeedingNowAction() {
        // Notifikace „Krmím teď" → nastavíme flag, RootView ho přečte
        // při scenePhase=.active a startne sezení s default prsem.
        // UserDefaults.standard — App Group sdílení nefunguje přes AltStore re-sign.
        UserDefaults.standard.set(true, forKey: "pendingStartFromReminder")
    }

    private func handleSnoozeAction(minutes: Int) {
        // Snooze běží v background — přeplánujeme reminder za N min od teď.
        Task { @MainActor in
            try? await reminderScheduler.scheduleAfter(
                endedAt: .now,
                intervalMinutes: minutes
            )
        }
    }
}
