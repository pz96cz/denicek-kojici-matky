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
        // SwiftData store žije v App Group sandboxu — KojeniWidgetExtension
        // čte/píše stejné DB přes App Intenty (Plan 3 Tasks 8-9).
        // TODO(prod): před prvním reálným deployem zvážit migraci legacy
        // default-sandbox store, pokud existuje na zařízení.
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(AppGroup.identifier)
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
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        defaults?.set(true, forKey: "pendingStartFromReminder")
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
