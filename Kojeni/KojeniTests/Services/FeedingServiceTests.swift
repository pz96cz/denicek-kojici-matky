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

    // MARK: - startSession

    @Test func startSession_inserts_active_session() throws {
        let (service, context) = makeService()
        let session = try service.startSession(breast: .left)

        #expect(session.initialBreast == .left)
        #expect(session.isActive)
        #expect(session.endedAt == nil)

        let all = try context.fetch(FetchDescriptor<FeedingSession>())
        #expect(all.count == 1)
        #expect(all.first?.initialBreast == .left)
    }

    @Test func startSession_with_explicit_date() throws {
        let (service, _) = makeService()
        let when = Date(timeIntervalSinceReferenceDate: 12345)
        let session = try service.startSession(breast: .right, at: when)
        #expect(session.startedAt == when)
        #expect(session.initialBreast == .right)
    }

    @Test func startSession_throws_when_active_session_exists() throws {
        let (service, _) = makeService()
        _ = try service.startSession(breast: .left)

        #expect(throws: FeedingServiceError.sessionAlreadyActive) {
            try service.startSession(breast: .right)
        }
    }

    @Test func startSession_after_previous_ended_is_allowed() throws {
        let (service, context) = makeService()
        let first = try service.startSession(breast: .left)
        first.endedAt = .now
        try context.save()

        let second = try service.startSession(breast: .right)
        #expect(second.initialBreast == .right)
        #expect(second.isActive)
    }
}
