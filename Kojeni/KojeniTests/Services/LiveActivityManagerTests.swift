import Testing
import Foundation
import ActivityKit
@testable import Kojeni

@Suite @MainActor
struct LiveActivityManagerTests {

    @Test func init_with_no_running_activity_has_nil_current() {
        // Předpoklad: testy neběží paralelně s reálnou LA.
        // Pokud by někdy běžela LA (např. lokální dev v paralelní invokaci),
        // tento test bude flaky — refaktor na DI Activity poolu v Plan 6.
        let manager = LiveActivityManager()
        #expect(manager.currentActivity == nil)
    }

    @Test func end_when_no_activity_is_noop() async {
        let manager = LiveActivityManager()
        await manager.end()   // nesmí spadnout
        #expect(manager.currentActivity == nil)
    }

    @Test func update_when_no_activity_is_noop() async {
        let manager = LiveActivityManager()
        await manager.update(currentBreast: .right)   // nesmí spadnout
        #expect(manager.currentActivity == nil)
    }

    @Test func start_when_activities_disabled_or_already_running_is_noop() {
        // Bez running aktivity má start dva guardy: areActivitiesEnabled
        // a duplicate-start. Aspoň jedním z nich projde — buď nezapne LA
        // (Low Power Mode / iOS Settings), nebo zapne 1× a druhé volání
        // už ne. currentActivity nesmí "duplikovat" nebo crashnout.
        let manager = LiveActivityManager()
        manager.start(sessionID: "dup-test", startedAt: .now, currentBreast: .left)
        let firstState = manager.currentActivity
        manager.start(sessionID: "dup-test-2", startedAt: .now, currentBreast: .right)
        let secondState = manager.currentActivity
        // Pokud první start uspěl (LA enabled), druhé volání musí být no-op
        // a state zůstává totožný. Pokud LA disabled, oba state == nil.
        #expect(firstState?.id == secondState?.id)
    }
}
