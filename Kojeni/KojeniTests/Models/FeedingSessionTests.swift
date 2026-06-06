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

    // MARK: - segments()

    @Test func segments_for_session_without_changes_returns_single_segment() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = start.addingTimeInterval(600)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.endedAt = end

        let segments = session.segments()

        #expect(segments.count == 1)
        #expect(segments[0].breast == .left)
        #expect(segments[0].start == start)
        #expect(segments[0].end == end)
    }

    @Test func segments_for_session_with_one_change_returns_two_segments() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let mid = start.addingTimeInterval(720)
        let end = start.addingTimeInterval(1080)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.endedAt = end
        session.breastChanges = [BreastChange(at: mid, to: .right)]

        let segments = session.segments()

        #expect(segments.count == 2)
        #expect(segments[0].breast == .left)
        #expect(segments[0].start == start)
        #expect(segments[0].end == mid)
        #expect(segments[1].breast == .right)
        #expect(segments[1].start == mid)
        #expect(segments[1].end == end)
    }

    @Test func segments_for_active_session_uses_now_as_end_of_last_segment() {
        let start = Date.now.addingTimeInterval(-300)
        let session = FeedingSession(startedAt: start, initialBreast: .left)

        let segments = session.segments()

        #expect(segments.count == 1)
        #expect(segments[0].breast == .left)
        let diff = abs(segments[0].end.timeIntervalSinceReferenceDate
                       - Date.now.timeIntervalSinceReferenceDate)
        #expect(diff < 1.0)
    }

    @Test func segments_sorts_changes_by_time() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let t1 = start.addingTimeInterval(60)
        let t2 = start.addingTimeInterval(120)
        let end = start.addingTimeInterval(180)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.endedAt = end
        session.breastChanges = [
            BreastChange(at: t2, to: .left),
            BreastChange(at: t1, to: .right),
        ]

        let segments = session.segments()

        #expect(segments.count == 3)
        #expect(segments[0].breast == .left)
        #expect(segments[0].end == t1)
        #expect(segments[1].breast == .right)
        #expect(segments[1].end == t2)
        #expect(segments[2].breast == .left)
        #expect(segments[2].end == end)
    }
}
