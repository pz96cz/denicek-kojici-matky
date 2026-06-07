import SwiftUI
import SwiftData

@main
struct KojeniApp: App {

    @State private var liveActivity = LiveActivityManager()

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
        }
        .modelContainer(container)
    }
}
