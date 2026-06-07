import Testing
import Foundation
@testable import Kojeni

@Suite
struct FeedingAttributesTests {

    @Test func encodes_and_decodes_attributes() throws {
        let originalAttrs = FeedingAttributes(
            sessionID: "ABC-123",
            sessionStartedAt: Date(timeIntervalSinceReferenceDate: 50000)
        )
        let encoded = try JSONEncoder().encode(originalAttrs)
        let decoded = try JSONDecoder().decode(FeedingAttributes.self, from: encoded)

        #expect(decoded.sessionID == "ABC-123")
        #expect(decoded.sessionStartedAt == originalAttrs.sessionStartedAt)
    }

    @Test func encodes_and_decodes_content_state() throws {
        let original = FeedingAttributes.ContentState(currentBreast: .right)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FeedingAttributes.ContentState.self, from: encoded)

        #expect(decoded.currentBreast == .right)
    }

    @Test func content_state_equality() {
        let a = FeedingAttributes.ContentState(currentBreast: .left)
        let b = FeedingAttributes.ContentState(currentBreast: .left)
        let c = FeedingAttributes.ContentState(currentBreast: .right)
        #expect(a == b)
        #expect(a != c)
    }
}
