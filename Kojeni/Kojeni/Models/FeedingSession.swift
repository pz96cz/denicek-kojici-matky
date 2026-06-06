import Foundation
import SwiftData

@Model
final class FeedingSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var initialBreast: Breast
    var pumpedMl: Int?

    @Relationship(deleteRule: .cascade, inverse: \BreastChange.session)
    var breastChanges: [BreastChange] = []

    init(startedAt: Date, initialBreast: Breast) {
        self.id = UUID()
        self.startedAt = startedAt
        self.initialBreast = initialBreast
    }

    var isActive: Bool { endedAt == nil }

    var duration: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }

    var currentBreast: Breast {
        breastChanges.sorted { $0.at < $1.at }.last?.to ?? initialBreast
    }
}
