import Foundation
import ActivityKit

/// Atributy Live Activity pro běžící kojení.
/// `Self` (statická metadata) jsou neměnné po dobu existence aktivity.
/// `ContentState` (dynamická data) se aktualizují přes `activity.update(...)`.
///
/// `nonisolated` — typ je pure value-type bez state, používá ho App Intent
/// (async perform v non-MainActor kontextu). Xcode 26 default MainActor isolation
/// by jinak generovala Swift 6 warning na conformance access z widget procesu.
nonisolated struct FeedingAttributes: ActivityAttributes {

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
