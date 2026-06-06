import Testing
import Foundation
import SwiftData
@testable import Kojeni

@Suite @MainActor
struct DiaperServiceTests {

    private func makeService() -> (DiaperService, ModelContext) {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        return (DiaperService(context: context), context)
    }

    @Test func logPee_inserts_event_without_consistency() throws {
        let (service, context) = makeService()
        let when = Date(timeIntervalSinceReferenceDate: 1000)

        let event = try service.logPee(at: when)

        #expect(event.kind == .pee)
        #expect(event.consistency == nil)
        #expect(event.at == when)

        let all = try context.fetch(FetchDescriptor<DiaperEvent>())
        #expect(all.count == 1)
    }

    @Test func logPoo_inserts_event_with_consistency() throws {
        let (service, context) = makeService()
        let when = Date(timeIntervalSinceReferenceDate: 2000)

        let event = try service.logPoo(consistency: .normal, at: when)

        #expect(event.kind == .poo)
        #expect(event.consistency == .normal)
        #expect(event.at == when)

        let all = try context.fetch(FetchDescriptor<DiaperEvent>())
        #expect(all.count == 1)
    }

    @Test func logPoo_supports_all_consistencies() throws {
        let (service, context) = makeService()

        _ = try service.logPoo(consistency: .loose)
        _ = try service.logPoo(consistency: .normal)
        _ = try service.logPoo(consistency: .hard)

        let all = try context.fetch(FetchDescriptor<DiaperEvent>())
        #expect(all.count == 3)
        #expect(Set(all.compactMap { $0.consistency })
                == Set([.loose, .normal, .hard]))
    }
}
