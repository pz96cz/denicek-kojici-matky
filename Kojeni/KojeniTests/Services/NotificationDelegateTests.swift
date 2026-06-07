import Testing
import Foundation
import UserNotifications
@testable import Kojeni

@Suite @MainActor
struct NotificationDelegateTests {

    @Test func feeding_now_action_calls_onFeedingNow() async {
        var feedingNowCalled = false
        var snoozeCalled: Int? = nil
        let delegate = NotificationDelegate(
            onFeedingNow: { feedingNowCalled = true },
            onSnooze: { minutes in snoozeCalled = minutes }
        )

        await delegate.handleAction(identifier: ReminderScheduler.feedingNowActionID)

        #expect(feedingNowCalled == true)
        #expect(snoozeCalled == nil)
    }

    @Test func snooze_15_action_calls_onSnooze_with_15() async {
        var snoozedMinutes: Int? = nil
        let delegate = NotificationDelegate(
            onFeedingNow: {},
            onSnooze: { minutes in snoozedMinutes = minutes }
        )

        await delegate.handleAction(identifier: ReminderScheduler.snooze15ActionID)

        #expect(snoozedMinutes == 15)
    }

    @Test func snooze_30_action_calls_onSnooze_with_30() async {
        var snoozedMinutes: Int? = nil
        let delegate = NotificationDelegate(
            onFeedingNow: {},
            onSnooze: { minutes in snoozedMinutes = minutes }
        )

        await delegate.handleAction(identifier: ReminderScheduler.snooze30ActionID)

        #expect(snoozedMinutes == 30)
    }

    @Test func unknown_action_is_noop() async {
        var feedingNowCalled = false
        var snoozeCalled: Int? = nil
        let delegate = NotificationDelegate(
            onFeedingNow: { feedingNowCalled = true },
            onSnooze: { minutes in snoozeCalled = minutes }
        )

        await delegate.handleAction(identifier: "garbage-action-id")

        #expect(feedingNowCalled == false)
        #expect(snoozeCalled == nil)
    }
}
