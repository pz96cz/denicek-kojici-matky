import Foundation
import SwiftData

@MainActor
final class FeedingService {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Vrátí aktivní (běžící) sezení, nebo `nil` pokud žádné neběží.
    /// V DB je z invariantu maximálně 1 aktivní sezení.
    func activeSession() throws -> FeedingSession? {
        let descriptor = FetchDescriptor<FeedingSession>(
            predicate: #Predicate { $0.endedAt == nil }
        )
        return try context.fetch(descriptor).first
    }

    /// Spustí nové sezení s daným prsem.
    /// Throws `sessionAlreadyActive` pokud už nějaké aktivní existuje.
    @discardableResult
    func startSession(breast: Breast, at date: Date = .now) throws -> FeedingSession {
        if try activeSession() != nil {
            throw FeedingServiceError.sessionAlreadyActive
        }
        let session = FeedingSession(startedAt: date, initialBreast: breast)
        context.insert(session)
        try context.save()
        return session
    }

    /// Přepne na opačné prso v aktivním sezení. No-op když žádné neběží.
    /// Vrací nové aktuální prso, nebo `nil` při no-op.
    @discardableResult
    func switchBreast(at date: Date = .now) throws -> Breast? {
        guard let session = try activeSession() else { return nil }
        let next = session.currentBreast.opposite
        let change = BreastChange(at: date, to: next)
        change.session = session
        session.breastChanges.append(change)
        try context.save()
        return next
    }
}
