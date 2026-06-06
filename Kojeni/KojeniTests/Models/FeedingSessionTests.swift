import Testing
import Foundation
import SwiftData
@testable import Kojeni

@Suite @MainActor
struct FeedingSessionTests {

    @Test func new_session_is_active() {
        let session = FeedingSession(startedAt: .now, initialBreast: .left)
        #expect(session.isActive)
        #expect(session.endedAt == nil)
    }

    @Test func ended_session_is_not_active() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = start.addingTimeInterval(600)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.endedAt = end
        #expect(!session.isActive)
    }

    @Test func duration_for_ended_session() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = start.addingTimeInterval(900)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.endedAt = end
        #expect(abs(session.duration - 900) < 0.001)
    }

    @Test func duration_for_active_session_uses_now() {
        let start = Date.now.addingTimeInterval(-60)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        #expect(abs(session.duration - 60) < 0.5)
    }

    @Test func currentBreast_without_changes_returns_initial() {
        let session = FeedingSession(startedAt: .now, initialBreast: .right)
        #expect(session.currentBreast == .right)
    }

    @Test func currentBreast_returns_last_change() {
        let session = FeedingSession(startedAt: .now, initialBreast: .left)
        let t1 = Date.now.addingTimeInterval(60)
        let t2 = Date.now.addingTimeInterval(120)
        session.breastChanges = [
            BreastChange(at: t1, to: .right),
            BreastChange(at: t2, to: .left),
        ]
        #expect(session.currentBreast == .left)
    }

    @Test func currentBreast_sorts_changes_by_time() {
        let session = FeedingSession(startedAt: .now, initialBreast: .left)
        let t1 = Date.now.addingTimeInterval(60)
        let t2 = Date.now.addingTimeInterval(120)
        session.breastChanges = [
            BreastChange(at: t2, to: .left),
            BreastChange(at: t1, to: .right),
        ]
        #expect(session.currentBreast == .left)
    }

    @Test func swiftdata_roundtrip() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.breastChanges = [BreastChange(at: start.addingTimeInterval(60), to: .right)]
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<FeedingSession>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.initialBreast == .left)
        #expect(fetched.first?.breastChanges.count == 1)
        #expect(fetched.first?.breastChanges.first?.to == .right)
    }
}
