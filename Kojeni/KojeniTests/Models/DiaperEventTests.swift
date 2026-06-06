import Testing
import Foundation
import SwiftData
@testable import Kojeni

@Suite @MainActor
struct DiaperEventTests {

    @Test func pee_event_has_no_consistency() {
        let event = DiaperEvent(at: .now, kind: .pee)
        #expect(event.kind == .pee)
        #expect(event.consistency == nil)
    }

    @Test func poo_event_with_consistency() {
        let event = DiaperEvent(at: .now, kind: .poo, consistency: .normal)
        #expect(event.kind == .poo)
        #expect(event.consistency == .normal)
    }

    @Test func pee_event_ignores_consistency_argument() {
        let event = DiaperEvent(at: .now, kind: .pee, consistency: .normal)
        #expect(event.consistency == nil, "Pee event must drop consistency argument")
    }

    @Test func swiftdata_roundtrip() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        let event = DiaperEvent(at: .now, kind: .poo, consistency: .loose)
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DiaperEvent>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.kind == .poo)
        #expect(fetched.first?.consistency == .loose)
    }
}
