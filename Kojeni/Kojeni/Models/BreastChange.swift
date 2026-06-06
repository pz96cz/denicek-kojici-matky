import Foundation
import SwiftData

@Model
final class BreastChange {
    var id: UUID
    var at: Date
    var to: Breast
    var session: FeedingSession?

    init(at: Date, to: Breast) {
        self.id = UUID()
        self.at = at
        self.to = to
    }
}
