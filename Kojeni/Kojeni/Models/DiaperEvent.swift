import Foundation
import SwiftData

@Model
final class DiaperEvent {
    var id: UUID
    var at: Date
    var kind: DiaperKind
    var consistency: PooConsistency?

    init(at: Date, kind: DiaperKind, consistency: PooConsistency? = nil) {
        self.id = UUID()
        self.at = at
        self.kind = kind
        self.consistency = (kind == .poo) ? consistency : nil
    }
}
