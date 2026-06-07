import Foundation
import ActivityKit
import OSLog
import SwiftUI

@MainActor
@Observable
final class LiveActivityManager {

    @ObservationIgnored
    private let log = Logger(subsystem: "cz.zapletal.kojeni", category: "LiveActivity")

    /// Aktuálně běžící Live Activity. `nil` když žádná není.
    /// Při init() se re-attach na existující aktivitu (po restartu appky).
    private(set) var currentActivity: Activity<FeedingAttributes>?

    init() {
        // Re-attach: pokud po restartu existuje LA pro běžící sezení, napoj se.
        currentActivity = Activity<FeedingAttributes>.activities.first
        if let act = currentActivity {
            log.info("Re-attached to running activity \(act.id)")
        }
    }

    /// Spustí Live Activity pro dané sezení. No-op pokud activities zakázané
    /// (Low Power Mode, iOS Settings) nebo už jedna běží.
    func start(sessionID: String, startedAt: Date, currentBreast: Breast) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.warning("Live Activities disabled — skipping start")
            return
        }
        guard currentActivity == nil else {
            log.warning("Activity already running — skipping duplicate start")
            return
        }

        let attrs = FeedingAttributes(sessionID: sessionID, sessionStartedAt: startedAt)
        let state = FeedingAttributes.ContentState(currentBreast: currentBreast)
        do {
            currentActivity = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil   // local-only, žádné push tokeny
            )
            log.info("Started LA for session \(sessionID)")
        } catch {
            log.error("LA start failed: \(error.localizedDescription)")
        }
    }

    /// Aktualizuje prso na běžící Live Activity. Timer pokračuje bez resetu.
    func update(currentBreast: Breast) async {
        guard let activity = currentActivity else { return }
        let state = FeedingAttributes.ContentState(currentBreast: currentBreast)
        await activity.update(.init(state: state, staleDate: nil))
        log.debug("LA updated currentBreast=\(currentBreast.rawValue)")
    }

    /// Ukončí Live Activity. No-op když žádná neběží. Idempotentní.
    func end() async {
        guard let activity = currentActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
        log.info("LA ended")
    }
}
