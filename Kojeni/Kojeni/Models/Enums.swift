import Foundation

enum Breast: String, Codable, CaseIterable {
    case left = "L"
    case right = "R"

    var opposite: Breast {
        self == .left ? .right : .left
    }
}

enum DiaperKind: String, Codable, CaseIterable {
    case pee
    case poo
}

enum PooConsistency: String, Codable, CaseIterable {
    case loose
    case normal
    case hard
}
