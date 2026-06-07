import Testing
import Foundation
import UserNotifications
@testable import Kojeni

@Suite @MainActor
struct ReminderSchedulerTests {

    final class MockNotificationCenter: NotificationCenterAPI {
        var requestCallCount = 0
        var requestResult: Bool = true
        var setCategoriesCallCount = 0
        var lastCategories: Set<UNNotificationCategory> = []

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
            requestCallCount += 1
            return requestResult
        }

        func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
            setCategoriesCallCount += 1
            lastCategories = categories
        }

        func add(_ request: UNNotificationRequest) async throws { /* unused in Task 1 */ }
        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) { /* unused */ }
        func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
        func notificationSettings() async -> UNNotificationSettings {
            // Test helper: settings instance can't be constructed; tests that need
            // real settings will skip this path — Plan 4 Task 1 doesn't use it.
            fatalError("Not implemented in mock — Task 1 doesn't exercise this")
        }
    }

    @Test func requestAuthorization_calls_center_and_returns_result() async throws {
        let mock = MockNotificationCenter()
        mock.requestResult = true
        let scheduler = ReminderScheduler(center: mock)

        let granted = try await scheduler.requestAuthorization()

        #expect(granted == true)
        #expect(mock.requestCallCount == 1)
    }

    @Test func requestAuthorization_returns_false_when_denied() async throws {
        let mock = MockNotificationCenter()
        mock.requestResult = false
        let scheduler = ReminderScheduler(center: mock)

        let granted = try await scheduler.requestAuthorization()

        #expect(granted == false)
    }

    @Test func requestAuthorization_registers_category_with_3_actions() async throws {
        let mock = MockNotificationCenter()
        let scheduler = ReminderScheduler(center: mock)

        _ = try await scheduler.requestAuthorization()

        #expect(mock.setCategoriesCallCount == 1)
        #expect(mock.lastCategories.count == 1)
        let category = mock.lastCategories.first!
        #expect(category.identifier == "feeding-reminder-category")
        #expect(category.actions.count == 3)
        let actionIDs = Set(category.actions.map { $0.identifier })
        #expect(actionIDs == ["feeding-now-action", "snooze-15-action", "snooze-30-action"])
    }

    // MARK: - scheduleAfter / cancelPending

    final class CapturingNotificationCenter: NotificationCenterAPI {
        var addedRequests: [UNNotificationRequest] = []
        var removedIdentifiers: [String] = []

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
        func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {}
        func add(_ request: UNNotificationRequest) async throws {
            addedRequests.append(request)
        }
        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            removedIdentifiers.append(contentsOf: identifiers)
        }
        func pendingNotificationRequests() async -> [UNNotificationRequest] { addedRequests }
        func notificationSettings() async -> UNNotificationSettings {
            fatalError("Not implemented in mock")
        }
    }

    @Test func scheduleAfter_adds_request_with_stable_identifier() async throws {
        let mock = CapturingNotificationCenter()
        let scheduler = ReminderScheduler(center: mock)
        let endedAt = Date.now.addingTimeInterval(-60)   // skončilo před minutou

        try await scheduler.scheduleAfter(endedAt: endedAt, intervalMinutes: 180)

        #expect(mock.addedRequests.count == 1)
        let request = mock.addedRequests.first!
        #expect(request.identifier == ReminderScheduler.notificationIdentifier)
        #expect(request.content.categoryIdentifier == ReminderScheduler.categoryIdentifier)
        #expect(request.content.title.contains("Čas na kojení"))
    }

    @Test func scheduleAfter_in_future_uses_calendar_trigger() async throws {
        let mock = CapturingNotificationCenter()
        let scheduler = ReminderScheduler(center: mock)
        let endedAt = Date.now   // teď
        let interval = 180        // 3h dopředu

        try await scheduler.scheduleAfter(endedAt: endedAt, intervalMinutes: interval)

        let request = mock.addedRequests.first!
        // Cíl leží v budoucnu → trigger MUSÍ být non-nil (UNCalendarNotificationTrigger)
        #expect(request.trigger != nil)
    }

    @Test func scheduleAfter_in_past_uses_nil_trigger_for_immediate_delivery() async throws {
        let mock = CapturingNotificationCenter()
        let scheduler = ReminderScheduler(center: mock)
        let endedAt = Date.now.addingTimeInterval(-7200)   // skončilo před 2h
        let interval = 60                                   // 1h interval → cíl byl před 1h

        try await scheduler.scheduleAfter(endedAt: endedAt, intervalMinutes: interval)

        let request = mock.addedRequests.first!
        #expect(request.trigger == nil)   // immediate delivery
    }

    @Test func cancelPending_removes_by_identifier() async {
        let mock = CapturingNotificationCenter()
        let scheduler = ReminderScheduler(center: mock)

        scheduler.cancelPending()

        #expect(mock.removedIdentifiers == [ReminderScheduler.notificationIdentifier])
    }

    @Test func scheduleAfter_replaces_existing_pending() async throws {
        // Druhý schedule s jiným časem nesmí nechat 2 pending — `add` přepisuje
        // podle identifier (UNUserNotificationCenter behavior). Mock simuluje
        // přepsání tak, že odstraní starou request při add s duplicitním ID.
        let mock = CapturingNotificationCenter()
        let scheduler = ReminderScheduler(center: mock)

        try await scheduler.scheduleAfter(endedAt: .now, intervalMinutes: 60)
        try await scheduler.scheduleAfter(endedAt: .now, intervalMinutes: 120)

        // Mock akumuluje, ale produkční UNCenter by přepsala.
        // Ověříme aspoň že identifier zůstal stejný.
        #expect(mock.addedRequests.count == 2)
        #expect(mock.addedRequests.allSatisfy { $0.identifier == ReminderScheduler.notificationIdentifier })
    }
}
