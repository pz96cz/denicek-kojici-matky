import Testing
import Foundation
import SwiftData
@testable import Kojeni

@Suite @MainActor
struct FeedingServiceTests {

    private func makeService() -> (FeedingService, ModelContext) {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        return (FeedingService(context: context), context)
    }

    @Test func activeSession_returns_nil_when_db_empty() throws {
        let (service, _) = makeService()
        #expect(try service.activeSession() == nil)
    }
}
