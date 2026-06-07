import AppIntents
import ActivityKit
import SwiftData
import Foundation
import OSLog

/// Tlačítko „Přehodit prso" v Live Activity.
/// Běží v Widget Extension procesu — neotvírá hlavní app, mamka nemusí odemykat.
struct SwitchBreastIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "Přehodit prso"

    init() {}

    func perform() async throws -> some IntentResult {
        let log = Logger(subsystem: "cz.zapletal.kojeni", category: "SwitchBreastIntent")

        // 1. Sdílený SwiftData container (App Group)
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

        // 2. Přepnutí přes FeedingService (Plan 2)
        let newBreast = try await MainActor.run { () -> Breast? in
            let context = ModelContext(container)
            let service = FeedingService(context: context)
            return try service.switchBreast()
        }
        guard let newBreast else {
            log.warning("switchBreast returned nil — no active session, no-op")
            return .result()
        }

        // 3. Update Live Activity in-place
        if let activity = Activity<FeedingAttributes>.activities.first {
            await activity.update(.init(
                state: FeedingAttributes.ContentState(currentBreast: newBreast),
                staleDate: nil
            ))
            log.info("LA updated currentBreast=\(newBreast.rawValue)")
        } else {
            log.warning("No Live Activity to update")
        }

        return .result()
    }
}
