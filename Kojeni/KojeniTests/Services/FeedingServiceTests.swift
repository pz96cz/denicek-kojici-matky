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

    // MARK: - switchBreast

    @Test func switchBreast_appends_change_and_switches_to_opposite() throws {
        let (service, _) = makeService()
        _ = try service.startSession(breast: .left)

        let newBreast = try service.switchBreast()

        #expect(newBreast == .right)
        let session = try service.activeSession()
        #expect(session?.breastChanges.count == 1)
        #expect(session?.currentBreast == .right)
        #expect(session?.breastChanges.first?.to == .right)
    }

    @Test func switchBreast_does_not_change_startedAt() throws {
        let (service, _) = makeService()
        let session = try service.startSession(breast: .left)
        let originalStart = session.startedAt

        _ = try service.switchBreast()

        let after = try service.activeSession()
        #expect(after?.startedAt == originalStart)
    }

    @Test func switchBreast_multiple_times_alternates() throws {
        let (service, _) = makeService()
        _ = try service.startSession(breast: .left)

        _ = try service.switchBreast()  // → R
        _ = try service.switchBreast()  // → L
        _ = try service.switchBreast()  // → R

        let session = try service.activeSession()
        #expect(session?.breastChanges.count == 3)
        #expect(session?.currentBreast == .right)
    }

    @Test func switchBreast_returns_nil_when_no_active_session() throws {
        let (service, _) = makeService()
        let result = try service.switchBreast()
        #expect(result == nil)
    }

    @Test func switchBreast_uses_provided_date() throws {
        let (service, _) = makeService()
        _ = try service.startSession(breast: .left)
        let when = Date(timeIntervalSinceReferenceDate: 99999)

        _ = try service.switchBreast(at: when)

        let session = try service.activeSession()
        #expect(session?.breastChanges.first?.at == when)
    }
}
