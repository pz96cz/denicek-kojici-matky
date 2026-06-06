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
}
