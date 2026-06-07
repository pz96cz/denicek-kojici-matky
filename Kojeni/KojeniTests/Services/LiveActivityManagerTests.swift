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
}
