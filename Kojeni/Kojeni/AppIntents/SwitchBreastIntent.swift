import AppIntents
import ActivityKit
import SwiftData
import Foundation
import OSLog

/// Tlačítko „Přehodit prso" v Live Activity.
/// `openAppWhenRun = true` — App Group container nelze sdílet přes AltStore re-sign
/// na free Apple ID, takže intent musí běžet v main app procesu kde má přístup
/// k default sandbox containeru. Mamka musí odemknout telefon.
struct SwitchBreastIntent: AppIntent {

    static var title: LocalizedStringResource = "Přehodit prso"
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        let log = Logger(subsystem: "cz.zapletal.kojeni", category: "SwitchBreastIntent")

        // Default sandbox container (sdílený s main app jelikož intent běží v main procesu)
        let schema = Schema([
            FeedingSession.self,
            BreastChange.self,
            DiaperEvent.self,
            AppSettings.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])

        let newBreast = try await MainActor.run { () -> Breast? in
            let context = ModelContext(container)
            let service = FeedingService(context: context)
            return try service.switchBreast()
        }
        guard let newBreast else {
            log.warning("switchBreast returned nil — no active session, no-op")
            return .result()
        }

        if let activity = Activity<FeedingAttributes>.activities.first {
            await activity.update(.init(
                state: FeedingAttributes.ContentState(currentBreast: newBreast),
                staleDate: nil
            ))
            log.info("LA updated currentBreast=\(newBreast.rawValue)")
        }

        return .result()
    }
}
