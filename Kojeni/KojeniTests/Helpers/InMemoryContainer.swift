import Foundation
import SwiftData
@testable import Kojeni

enum InMemoryContainer {

    @MainActor
    static func make() -> ModelContainer {
        let schema = Schema([
            FeedingSession.self,
            BreastChange.self,
            DiaperEvent.self,
            AppSettings.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
