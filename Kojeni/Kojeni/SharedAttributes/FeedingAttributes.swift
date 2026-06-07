import Foundation
import ActivityKit

/// Atributy Live Activity pro běžící kojení.
/// `Self` (statická metadata) jsou neměnné po dobu existence aktivity.
/// `ContentState` (dynamická data) se aktualizují přes `activity.update(...)`.
struct FeedingAttributes: ActivityAttributes {

    /// PersistentIdentifier sezení jako string — App Intent z widgetu si přes něj
    /// dohledá `FeedingSession` v shared SwiftData containeru.
    var sessionID: String

    /// Reference pro `Text(timerInterval:)` — Live Activity widget renderuje
    /// počítadlo bez aktivního Timeru. Nemění se po dobu aktivity.
    var sessionStartedAt: Date

    struct ContentState: Codable, Hashable {
        /// Prso, kterým mamka aktuálně kojí. Mění se přes `activity.update(...)`.
        var currentBreast: Breast
    }
}
