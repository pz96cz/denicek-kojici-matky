import Foundation
import SwiftData

@MainActor
final class DiaperService {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func logPee(at date: Date = .now) throws -> DiaperEvent {
        let event = DiaperEvent(at: date, kind: .pee)
        context.insert(event)
        try context.save()
        return event
    }

    @discardableResult
    func logPoo(consistency: PooConsistency, at date: Date = .now) throws -> DiaperEvent {
        let event = DiaperEvent(at: date, kind: .poo, consistency: consistency)
        context.insert(event)
        try context.save()
        return event
    }
}
