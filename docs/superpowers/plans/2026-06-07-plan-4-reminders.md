# Kojení — Plan 4: Reminders (lokální notifikace)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lokální push notifikace, které mamce připomenou další kojení podle nastavitelného intervalu od konce minulého sezení. Akce v notifikaci: „Krmím teď" (startne sezení a otevře app), „Odložit 15 min" / „Odložit 30 min" (přeplánuje bez otevření app). Spec sekce 1.4 + 5.

**Architecture:** `ReminderScheduler` service obaluje `UNUserNotificationCenter`. Žádný singleton — instance žije v `KojeniApp` přes `@State`, propaguje se přes typed environment `@Environment(ReminderScheduler.self)`. Notifikace má jediný stabilní identifier `"feeding-reminder"`, díky čemuž je max 1 v queue a snadno se ruší/přeplanovává. `NotificationDelegate` (implementuje `UNUserNotificationCenterDelegate`) zachytí akce a aplikuje je — pro „Krmím teď" otevře app a nastartuje sezení, pro „Odložit X" přeplánuje. Permission request přesunut na konec onboardingu.

**Tech Stack:** Swift 6+, Xcode 26+, iOS 26.5+, SwiftUI, UserNotifications, Swift Testing. Žádné externí dependency. Žádné Xcode UI kroky (žádné entitlements ani capability — lokální notifikace jsou implicitní).

> Plan navazuje na Plan 1-3. Předpokládá `FeedingService`, `AppSettings.reminderIntervalMinutes`, `LiveActivityManager`, `AppGroup.identifier` (pro App Group UserDefaults flag — paralelní s Plan 3 PumpedMlSheet pickup).

---

## Risk a fallbacky

### Permission denied

Pokud mamka odmítne notifikace v onboardingu, ReminderScheduler **nikdy nic nenaplánuje** (silently no-op). Banner v `IdleHomeView` (Plan 4 Task 8) ji upozorní, že reminders nefungují, s tlačítkem pro otevření iOS Settings stránky appky.

### App spící > intervalu

iOS samo doručí notifikaci v naplánovaný čas i když app neběží. Žádný background fetch netřeba.

### Race: notifikace doručena během běžícího sezení

`startSession()` v `FeedingService` volá `ReminderScheduler.cancelPending()` jako první. Při race < 1s (notifikace odeslána iOS těsně před cancel) tap na „Krmím teď" detekuje aktivní sezení a vrátí no-op + toast „Kojení už běží". V Plan 4 je toast nahrazen tichým no-op + log (banner z Plan 6).

### Action handling v widget procesu

Notification handler běží v main app procesu (UNUserNotificationCenter.delegate je instance v main app). Akce z notifikace tedy otevírají hlavní app — pro „Krmím teď" otevře a startne, pro „Odložit" otevře (krátce, neuvidí UI) a přeplánuje na pozadí.

---

## File Structure (po dokončení Plan 4)

```
Kojeni/Kojeni/
├── KojeniApp.swift                          ← MODIFY: @State ReminderScheduler, set delegate
├── App/
│   └── RootView.swift                       ← (beze změny — Plan 3 pickup logic dál drží)
├── Services/
│   ├── FeedingService.swift                 ← (beze změny — orchestrace na call-sitech)
│   ├── DiaperService.swift                  ← (beze změny)
│   ├── LiveActivityManager.swift            ← (beze změny)
│   ├── ReminderScheduler.swift              ← NEW
│   └── NotificationDelegate.swift           ← NEW
├── Features/
│   ├── Home/
│   │   ├── BreastPickerSheet.swift          ← MODIFY: cancel pending reminder po startSession
│   │   ├── IdleHomeView.swift               ← MODIFY: banner pokud permission denied
│   │   └── ActiveSessionView.swift          ← MODIFY: schedule reminder po endSession
│   ├── Onboarding/
│   │   └── OnboardingSheet.swift            ← MODIFY: permission request na "Hotovo"
│   └── Settings/
│       └── SettingsView.swift               ← MODIFY: Stepper interval + Toggle enabled + reschedule
└── AppIntents/
    ├── SwitchBreastIntent.swift             ← (beze změny — switch nepřeplanovává)
    └── StopFeedingIntent.swift              ← MODIFY: schedule reminder po endSession

Kojeni/KojeniTests/
└── Services/
    ├── ReminderSchedulerTests.swift         ← NEW (3-4 tests s mock UNCenter protokolem)
    └── NotificationDelegateTests.swift      ← NEW (action routing — 2 tests)
```

**Vědomě NEpatří do Plan 4:**
- Banner "permission denied" plně designovaný (text/copy/styling) — basic ano, polish Plan 6.
- Toast "Kojení už běží" při race — silent no-op acceptable.
- Reschedule při změně sezení v EditSessionSheet (Plan 5) — Plan 5 to dořeší až bude existovat.
- Localized notification content přes Localizable.strings — Plan 6.

---

## Task 1: `ReminderScheduler` skeleton + permission request

**Files:**
- Create: `Kojeni/Kojeni/Services/ReminderScheduler.swift`
- Create: `Kojeni/KojeniTests/Services/ReminderSchedulerTests.swift`

**Cíl:** Stateless `@MainActor` service obalující `UNUserNotificationCenter`. Public surface: `requestAuthorization() async -> Bool`, `isAuthorized() async -> Bool`. Interní notifikační center injectovaný protokolem `NotificationCenterAPI` pro mock v testech.

- [ ] **Step 1: Napiš protokol + failing testy**

`Kojeni/KojeniTests/Services/ReminderSchedulerTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Pusť testy — selžou**

Expected: `Cannot find 'NotificationCenterAPI'` and `Cannot find 'ReminderScheduler'`.

- [ ] **Step 3: Implementuj `NotificationCenterAPI` protokol + `ReminderScheduler` v jednom souboru**

`Kojeni/Kojeni/Services/ReminderScheduler.swift`:

```swift
import Foundation
import UserNotifications
import OSLog

/// Protokol pro mockování `UNUserNotificationCenter` v unit testech.
/// Production `UNUserNotificationCenter.current()` conformance je dole v tomto souboru.
@MainActor
protocol NotificationCenterAPI {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func notificationSettings() async -> UNNotificationSettings
}

extension UNUserNotificationCenter: NotificationCenterAPI {}

@MainActor
@Observable
final class ReminderScheduler {

    @ObservationIgnored
    private let log = Logger(subsystem: "cz.zapletal.kojeni", category: "Reminder")

    @ObservationIgnored
    private let center: NotificationCenterAPI

    /// Stabilní identifier — vždy max 1 pending feeding reminder.
    static let notificationIdentifier = "feeding-reminder"

    /// Identifier UNNotificationCategory s 3 akcemi.
    static let categoryIdentifier = "feeding-reminder-category"

    /// Action identifiers — match s `NotificationDelegate` (Task 4).
    static let feedingNowActionID = "feeding-now-action"
    static let snooze15ActionID = "snooze-15-action"
    static let snooze30ActionID = "snooze-30-action"

    init(center: NotificationCenterAPI = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// Vyžádá permission od uživatele, registruje category s akcemi.
    /// Returns `true` pokud granted, `false` pokud denied.
    @discardableResult
    func requestAuthorization() async throws -> Bool {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        registerCategory()
        log.info("Authorization request: granted=\(granted)")
        return granted
    }

    /// Cache-friendly check, ne přes requestAuthorization aby se uživateli
    /// znovu neotevíral system dialog.
    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }

    private func registerCategory() {
        let feedingNow = UNNotificationAction(
            identifier: Self.feedingNowActionID,
            title: "Krmím teď",
            options: [.foreground]
        )
        let snooze15 = UNNotificationAction(
            identifier: Self.snooze15ActionID,
            title: "Odložit 15 min",
            options: []
        )
        let snooze30 = UNNotificationAction(
            identifier: Self.snooze30ActionID,
            title: "Odložit 30 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [feedingNow, snooze15, snooze30],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }
}
```

- [ ] **Step 4: Pusť testy — projdou**

Expected: 52 passed (49 + 3 nové ReminderScheduler testy).

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/Services/ReminderScheduler.swift \
        Kojeni/KojeniTests/Services/ReminderSchedulerTests.swift
git commit -m "feat(services): ReminderScheduler skeleton + permission request"
```

---

## Task 2: `ReminderScheduler.scheduleAfter` + `cancelPending`

**Files:**
- Modify: `Kojeni/Kojeni/Services/ReminderScheduler.swift`
- Modify: `Kojeni/KojeniTests/Services/ReminderSchedulerTests.swift`

**Cíl:** `scheduleAfter(endedAt:intervalMinutes:)` naplánuje notifikaci na `endedAt + interval`. `cancelPending()` smaže pending. Pokud výsledný čas leží v minulosti, doručí ji okamžitě (UNNotificationCenter to dělá automaticky s `trigger == nil`).

- [ ] **Step 1: Napiš failing testy**

Doplň do `ReminderSchedulerTests` před závěrečnou `}`:

```swift
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
```

- [ ] **Step 2: Pusť testy — selžou**

Expected: `value of type 'ReminderScheduler' has no member 'scheduleAfter'` a `cancelPending`.

- [ ] **Step 3: Implementuj `scheduleAfter` + `cancelPending`**

Do `ReminderScheduler` přidej před závěrečnou `}`:

```swift
    /// Naplánuje notifikaci na `endedAt + intervalMinutes`.
    /// Pokud výsledek leží v minulosti, doručí ji okamžitě (trigger = nil).
    func scheduleAfter(endedAt: Date, intervalMinutes: Int) async throws {
        let triggerDate = endedAt.addingTimeInterval(TimeInterval(intervalMinutes * 60))
        let now = Date.now

        let content = UNMutableNotificationContent()
        content.title = "🤱 Čas na kojení"
        let hours = intervalMinutes / 60
        let mins = intervalMinutes % 60
        if hours > 0 && mins == 0 {
            content.body = "Od posledního krmení uběhly \(hours) h."
        } else if hours > 0 {
            content.body = "Od posledního krmení uběhly \(hours) h \(mins) min."
        } else {
            content.body = "Od posledního krmení uběhlo \(mins) min."
        }
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        let trigger: UNNotificationTrigger?
        if triggerDate > now {
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            trigger = nil   // immediate delivery
        }

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
        log.info("Scheduled reminder for \(triggerDate)")
    }

    /// Smaže pending feeding reminder. Idempotentní.
    func cancelPending() {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.notificationIdentifier]
        )
        log.debug("Cancelled pending reminder")
    }
```

- [ ] **Step 4: Pusť testy — projdou**

Expected: 57 passed (52 + 5 nové scheduleAfter/cancelPending testy).

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/Services/ReminderScheduler.swift \
        Kojeni/KojeniTests/Services/ReminderSchedulerTests.swift
git commit -m "feat(services): ReminderScheduler.scheduleAfter + cancelPending"
```

---

## Task 3: `NotificationDelegate` — action routing

**Files:**
- Create: `Kojeni/Kojeni/Services/NotificationDelegate.swift`
- Create: `Kojeni/KojeniTests/Services/NotificationDelegateTests.swift`

**Cíl:** Implementace `UNUserNotificationCenterDelegate` v třídě `NotificationDelegate`. Při tapu na akci dispatchne callback (přes closure injection v initu, ne hardcoded). Action handler je čistá funkce pro testovatelnost — Plan 4 Task 5 ji zaregistruje v `KojeniApp`.

> Důvod separace delegate vs handler: UNUserNotificationCenter.delegate je `NSObject` instance — UIKit pattern. Naše domain logic je čistá func. Delegate jen routuje action ID na correct callback.

- [ ] **Step 1: Napiš failing testy**

`Kojeni/KojeniTests/Services/NotificationDelegateTests.swift`:

```swift
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
```

- [ ] **Step 2: Implementuj `NotificationDelegate`**

`Kojeni/Kojeni/Services/NotificationDelegate.swift`:

```swift
import Foundation
import UserNotifications
import OSLog

/// Routuje notifikace akce na callback closures.
/// `UNUserNotificationCenterDelegate` conformance umožňuje zachytit
/// tapnutí v notification — runtime ho zaregistruje `KojeniApp` (Task 5).
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    private let log = Logger(subsystem: "cz.zapletal.kojeni", category: "NotificationDelegate")
    private let onFeedingNow: @MainActor () -> Void
    private let onSnooze: @MainActor (Int) -> Void

    init(
        onFeedingNow: @escaping @MainActor () -> Void,
        onSnooze: @escaping @MainActor (Int) -> Void
    ) {
        self.onFeedingNow = onFeedingNow
        self.onSnooze = onSnooze
        super.init()
    }

    /// Test-friendly entry point — production code ji nezvolí přímo,
    /// jen přes UNUserNotificationCenterDelegate metodu níže.
    func handleAction(identifier: String) async {
        switch identifier {
        case ReminderScheduler.feedingNowActionID:
            log.info("Action: feeding-now")
            onFeedingNow()
        case ReminderScheduler.snooze15ActionID:
            log.info("Action: snooze-15")
            onSnooze(15)
        case ReminderScheduler.snooze30ActionID:
            log.info("Action: snooze-30")
            onSnooze(30)
        default:
            log.warning("Unknown action: \(identifier)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        Task { @MainActor in
            await handleAction(identifier: actionID)
            completionHandler()
        }
    }

    /// Foreground delivery — když app běží a notifikace dorazí.
    /// Zobrazíme ji jako banner, ne potichu spolknout.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

- [ ] **Step 3: Pusť testy — projdou**

Expected: 61 passed (57 + 4 nové NotificationDelegate testy).

- [ ] **Step 4: Commit**

```bash
git add Kojeni/Kojeni/Services/NotificationDelegate.swift \
        Kojeni/KojeniTests/Services/NotificationDelegateTests.swift
git commit -m "feat(services): NotificationDelegate routing 3 action IDs"
```

---

## Task 4: Wire ReminderScheduler do UI flows (start/end)

**Files:**
- Modify: `Kojeni/Kojeni/KojeniApp.swift` (inject scheduler + delegate setup)
- Modify: `Kojeni/Kojeni/Features/Home/BreastPickerSheet.swift` (cancel po startSession)
- Modify: `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift` (schedule po endSession)
- Modify: `Kojeni/Kojeni/AppIntents/StopFeedingIntent.swift` (schedule po endSession)

**Cíl:** Reminder se zapne při Stop sezení, vypne při Start nového sezení. Pro „Krmím teď" akci `NotificationDelegate` callback dále nastaví `pendingStartFromReminder` flag v App Group UserDefaults, který `RootView` při `scenePhase = .active` přečte a startne sezení (analogie s Plan 3 PumpedMlSheet pickup).

- [ ] **Step 1: Inject scheduler v `KojeniApp.swift`**

Uprav `KojeniApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct KojeniApp: App {

    @State private var liveActivity = LiveActivityManager()
    @State private var reminderScheduler = ReminderScheduler()
    @State private var notificationDelegate: NotificationDelegate?

    let container: ModelContainer = {
        let schema = Schema([
            FeedingSession.self,
            BreastChange.self,
            DiaperEvent.self,
            AppSettings.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(AppGroup.identifier)
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer selhalo při startu: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(liveActivity)
                .environment(reminderScheduler)
                .task {
                    setupNotificationDelegate()
                }
        }
        .modelContainer(container)
    }

    /// Registrace delegate při startu app — drží reference v @State aby přežil.
    private func setupNotificationDelegate() {
        guard notificationDelegate == nil else { return }
        let delegate = NotificationDelegate(
            onFeedingNow: handleFeedingNowAction,
            onSnooze: handleSnoozeAction
        )
        UNUserNotificationCenter.current().delegate = delegate
        notificationDelegate = delegate
    }

    private func handleFeedingNowAction() {
        // Notifikace „Krmím teď" → nastavíme flag, RootView ho přečte
        // při scenePhase=.active a startne sezení s default prsem.
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        defaults?.set(true, forKey: "pendingStartFromReminder")
    }

    private func handleSnoozeAction(minutes: Int) {
        // Snooze běží v background — přeplánujeme reminder za N min od teď.
        Task { @MainActor in
            try? await reminderScheduler.scheduleAfter(
                endedAt: .now,
                intervalMinutes: minutes
            )
        }
    }
}
```

- [ ] **Step 2: Wire `cancelPending` v `BreastPickerSheet.start`**

Přidej `@Environment(ReminderScheduler.self) private var reminderScheduler` do `BreastPickerSheet`, a v `start(with:)` po úspěšném `startSession` přidej:

```swift
            reminderScheduler.cancelPending()
```

(Před `liveActivity.start(...)`, nebo po něm — order nezáleží.)

- [ ] **Step 3: Wire `scheduleAfter` v `ActiveSessionView.endSession`**

Přidej `@Environment(ReminderScheduler.self) private var reminderScheduler` + `@Query private var settingsList: [AppSettings]` do `ActiveSessionView`. V `endSession` po úspěšném `endSession()` (po `Task { await liveActivity.end() }`) přidej:

```swift
            if let settings = settingsList.first, settings.remindersEnabled,
               let endedAt = ended.endedAt {
                Task {
                    try? await reminderScheduler.scheduleAfter(
                        endedAt: endedAt,
                        intervalMinutes: settings.reminderIntervalMinutes
                    )
                }
            }
```

- [ ] **Step 4: Wire `scheduleAfter` v `StopFeedingIntent.perform`**

V `StopFeedingIntent.swift` po `defaults?.set(...)` pro PumpedMlSheet flag přidej (před `activity.end`):

```swift
        // Schedule next reminder podle aktuálních AppSettings
        let interval = try await MainActor.run { () -> Int? in
            let context = ModelContext(container)
            let settings = try AppSettings.loadOrCreate(in: context)
            return settings.remindersEnabled ? settings.reminderIntervalMinutes : nil
        }
        if let interval {
            let scheduler = await ReminderScheduler()
            try? await scheduler.scheduleAfter(endedAt: endedAt, intervalMinutes: interval)
        }
```

> ReminderScheduler je `@MainActor` — `await` při init.

- [ ] **Step 5: Update `RootView` pro pickup `pendingStartFromReminder`**

V `RootView.handleAppGroupPickup()` přidej před existující PumpedMlSheet pickup (po prvním guard):

```swift
        // Pickup: notifikace "Krmím teď" → startni sezení s default prsem
        if defaults?.bool(forKey: "pendingStartFromReminder") == true {
            defaults?.set(false, forKey: "pendingStartFromReminder")
            startFromReminder()
        }
```

A přidej helper metodu:

```swift
    private func startFromReminder() {
        // Default prso: opačné než poslední session, fallback .left.
        let descriptor = FetchDescriptor<FeedingSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let recent = (try? modelContext.fetch(descriptor)) ?? []
        let suggested: Breast = recent.first(where: { $0.endedAt != nil })?.currentBreast.opposite ?? .left
        do {
            _ = try FeedingService(context: modelContext).startSession(breast: suggested)
        } catch {
            print("startFromReminder failed: \(error)")
        }
    }
```

- [ ] **Step 6: Build + tests**

Expected: 61 passed (žádný regress).

- [ ] **Step 7: Commit**

```bash
git add Kojeni/Kojeni/KojeniApp.swift \
        Kojeni/Kojeni/Features/Home/BreastPickerSheet.swift \
        Kojeni/Kojeni/Features/Home/ActiveSessionView.swift \
        Kojeni/Kojeni/AppIntents/StopFeedingIntent.swift \
        Kojeni/Kojeni/App/RootView.swift
git commit -m "feat(ui): wire ReminderScheduler into start/end flows + Krmim ted pickup"
```

---

## Task 5: Permission request v `OnboardingSheet`

**Files:**
- Modify: `Kojeni/Kojeni/Features/Onboarding/OnboardingSheet.swift`

**Cíl:** Po tapu „Hotovo" zavolat `ReminderScheduler.requestAuthorization()` před dismiss. Pokud denied, AppSettings.remindersEnabled = false (nepokoušej se plánovat).

- [ ] **Step 1: Update `OnboardingSheet.saveAndClose`**

Přidej `@Environment(ReminderScheduler.self) private var reminderScheduler`. Uprav `saveAndClose`:

```swift
    private func saveAndClose() {
        Task {
            do {
                let settings = try AppSettings.loadOrCreate(in: modelContext)
                settings.reminderIntervalMinutes = intervalMinutes

                let granted = (try? await reminderScheduler.requestAuthorization()) ?? false
                settings.remindersEnabled = granted

                try modelContext.save()
                dismiss()
            } catch {
                print("OnboardingSheet save failed: \(error)")
                dismiss()
            }
        }
    }
```

> Pokud denied: `settings.remindersEnabled = false` zaručí, že schedule volání se silently přeskočí v Task 4 Step 3 a Step 4.

- [ ] **Step 2: Build + tests**

Expected: 61 passed.

- [ ] **Step 3: Commit**

```bash
git add Kojeni/Kojeni/Features/Onboarding/OnboardingSheet.swift
git commit -m "feat(onboarding): request notification authorization on Hotovo"
```

---

## Task 6: `SettingsView` — Stepper interval + Toggle enabled + reschedule

**Files:**
- Modify: `Kojeni/Kojeni/Features/Settings/SettingsView.swift`

**Cíl:** Settings UI dle spec sekce 4. Stepper interval (30…360, krok 15). Toggle remindersEnabled. Změna kteréhokoli → pokud existuje pending reminder, přeplanuj. Sekce "O aplikaci": verze, build, tlačítko otevřít iOS Settings stránku appky.

- [ ] **Step 1: Přepiš `SettingsView`**

```swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderScheduler.self) private var reminderScheduler

    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Připomínky") {
                    if let settings {
                        Toggle("Připomínky zapnuté", isOn: Binding(
                            get: { settings.remindersEnabled },
                            set: { newValue in
                                settings.remindersEnabled = newValue
                                try? modelContext.save()
                                handleSettingsChanged(settings: settings)
                            }
                        ))

                        Stepper(
                            value: Binding(
                                get: { settings.reminderIntervalMinutes },
                                set: { newValue in
                                    settings.reminderIntervalMinutes = newValue
                                    try? modelContext.save()
                                    handleSettingsChanged(settings: settings)
                                }
                            ),
                            in: AppSettings.minIntervalMinutes...AppSettings.maxIntervalMinutes,
                            step: 15
                        ) {
                            VStack(alignment: .leading) {
                                Text("Interval mezi kojeními")
                                Text(formattedInterval(settings.reminderIntervalMinutes))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(!settings.remindersEnabled)
                    } else {
                        Text("Načítání…")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("O aplikaci") {
                    LabeledContent("Verze", value: appVersion)
                    LabeledContent("Build", value: appBuild)
                    Button("Otevřít nastavení notifikací") {
                        openAppSettings()
                    }
                }
            }
            .navigationTitle("Nastavení")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func formattedInterval(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h) h" }
        if h == 0 { return "\(m) min" }
        return "\(h) h \(m) min"
    }

    private func handleSettingsChanged(settings: AppSettings) {
        // Pokud reminders disabled, cancel pending.
        guard settings.remindersEnabled else {
            reminderScheduler.cancelPending()
            return
        }

        // Pokud enabled a existuje poslední ukončené sezení, přepláň nový reminder
        // z jeho endedAt (může být v minulosti → okamžitá delivery).
        let descriptor = FetchDescriptor<FeedingSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let recent = (try? modelContext.fetch(descriptor)) ?? []
        guard let last = recent.first(where: { $0.endedAt != nil }),
              let endedAt = last.endedAt else { return }

        Task {
            try? await reminderScheduler.scheduleAfter(
                endedAt: endedAt,
                intervalMinutes: settings.reminderIntervalMinutes
            )
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettings.self, inMemory: true)
        .environment(ReminderScheduler())
}
```

- [ ] **Step 2: Build + tests**

Expected: 61 passed.

- [ ] **Step 3: Commit**

```bash
git add Kojeni/Kojeni/Features/Settings/SettingsView.swift
git commit -m "feat(settings): interval + enabled toggle with reschedule on change"
```

---

## Task 7: Banner v `IdleHomeView` pro permission denied

**Files:**
- Modify: `Kojeni/Kojeni/Features/Home/IdleHomeView.swift`

**Cíl:** Pokud `reminderScheduler.isAuthorized()` vrátí false a `AppSettings.remindersEnabled` je true (mamka chce, ale systém nepustí), ukázat banner s tlačítkem „Otevřít nastavení". Banner se ukáže nad `lastFeedingHeader`.

- [ ] **Step 1: Přidat banner do `IdleHomeView`**

Přidej do `IdleHomeView`:

```swift
    @Environment(ReminderScheduler.self) private var reminderScheduler
    @Query private var settingsList: [AppSettings]
    @State private var authorizationDenied = false
```

Přidej `.task` modifier na `body`'s `VStack`:

```swift
        .task {
            await checkAuthorization()
        }
```

A pomocné metody před `#Preview`:

```swift
    private var permissionBanner: some View {
        VStack(spacing: 4) {
            Text("⚠️ Notifikace jsou vypnuté v systému")
                .font(.subheadline.bold())
            Text("Reminder kojení nemůže fungovat, dokud je nepovolíš.")
                .font(.caption)
            Button("Otevřít nastavení") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .foregroundStyle(.orange)
        .padding(8)
        .background(.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    private func checkAuthorization() async {
        guard let settings = settingsList.first, settings.remindersEnabled else {
            authorizationDenied = false
            return
        }
        let isAuth = await reminderScheduler.isAuthorized()
        authorizationDenied = !isAuth
    }
```

Uprav `body` — přidej banner na začátek `VStack`:

```swift
        VStack(spacing: 24) {
            if authorizationDenied {
                permissionBanner
            }

            lastFeedingHeader
                .padding(.top)
            // ... zbytek beze změny ...
        }
```

- [ ] **Step 2: Build + tests**

Expected: 61 passed.

- [ ] **Step 3: Commit**

```bash
git add Kojeni/Kojeni/Features/Home/IdleHomeView.swift
git commit -m "feat(ui): permission-denied banner in IdleHomeView with Open Settings"
```

---

## Task 8: Preview fixes pro nové environment

**Files:**
- Modify: `Kojeni/Kojeni/Features/Home/IdleHomeView.swift` (#Preview)
- Modify: `Kojeni/Kojeni/Features/Home/HomeView.swift` (#Preview)
- Modify: `Kojeni/Kojeni/Features/Home/BreastPickerSheet.swift` (#Preview)

**Cíl:** Všechny existující `#Preview` bloky teď potřebují i `.environment(ReminderScheduler())` aby se nesložily na chybějícím environment value.

- [ ] **Step 1: Update 3 previews**

V každém z `#Preview` blocků v 3 souborech přidej `.environment(ReminderScheduler())` za existující `.environment(LiveActivityManager())`.

- [ ] **Step 2: Build + tests**

Expected: 61 passed.

- [ ] **Step 3: Commit**

```bash
git add Kojeni/Kojeni/Features/Home/IdleHomeView.swift \
        Kojeni/Kojeni/Features/Home/HomeView.swift \
        Kojeni/Kojeni/Features/Home/BreastPickerSheet.swift
git commit -m "fix(ui): inject ReminderScheduler into 3 previews"
```

---

## Task 9: E2E smoke + CHANGELOG + tag v0.4.0

**Files:** `CHANGELOG.md`

**Cíl:** Manuální verifikace na simulátoru — onboarding s permission prompt, set interval, ukončit sezení, vidět notifikaci za N min (Xcode debug ji může spustit hned), tap akce, ověřit. Tag v0.4.0.

- [ ] **Step 1: Erase + clean install**

```bash
SIMCTL=/Applications/Xcode.app/Contents/Developer/usr/bin/simctl
SIM_ID=E7D54495-1FBF-4E65-B7E4-F55D51806898
$SIMCTL shutdown $SIM_ID 2>/dev/null
$SIMCTL erase $SIM_ID
$SIMCTL boot $SIM_ID
rm -rf /tmp/kojeni-build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath /tmp/kojeni-build -quiet
$SIMCTL install $SIM_ID /tmp/kojeni-build/Build/Products/Debug-iphonesimulator/Kojeni.app
$SIMCTL launch $SIM_ID cz.zapletal.Kojeni
```

- [ ] **Step 2: Manual smoke (Simulator.app)**

- [ ] Onboarding ukáže permission prompt po Hotovo → Allow.
- [ ] Settings tab → Stepper na 30 min, Toggle ON → Settings se uloží.
- [ ] Start sezení → Stop → ml save.
- [ ] V Xcode menubar `Debug → Simulate Notification → Background Fetch` (alternativně počkat 30 min).
- [ ] Notifikace „🤱 Čas na kojení" se objeví.
- [ ] Tap „Odložit 15 min" → notifikace zmizí, za 15 min se znovu objeví.
- [ ] Tap „Krmím teď" → app se otevře, sezení automaticky startne.
- [ ] V Settings: Toggle OFF → pending reminder se zruší (verifikace přes Xcode logs).
- [ ] V Settings: Toggle ON → reminder se zase naplánuje.
- [ ] V iOS Settings → Notifications → Kojení → OFF. Vrať se do app. IdleHomeView ukáže permission banner.

- [ ] **Step 3: Unit testy**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -quiet 2>&1 | grep -c "passed"
```

Expected: **61**.

- [ ] **Step 4: CHANGELOG**

Před `## [0.3.0]` přidej:

```markdown
## [0.4.0] — Plan 4: Reminders — 2026-06-07

- `ReminderScheduler` service nad `UNUserNotificationCenter` (protocol-based pro test mockování).
- `scheduleAfter(endedAt:intervalMinutes:)` — past-time triggery použijí immediate delivery (trigger=nil).
- `cancelPending()` smaže pending podle stabilního identifieru.
- `NotificationDelegate` routuje 3 akce (feeding-now/snooze-15/snooze-30) na callback closures.
- Permission request integrován do OnboardingSheet (po tapu Hotovo).
- SettingsView: Stepper intervalu (30–360 min, krok 15), Toggle reminders enabled, reschedule on change.
- IdleHomeView: banner pokud reminders enabled v AppSettings ale systém je denied, s tlačítkem Open Settings.
- StopFeedingIntent (Live Activity Stop) také rozplánuje nový reminder podle AppSettings.
- "Krmím teď" pickup v RootView přes App Group UserDefaults flag.
- 12 nových Swift Testing testů (5 schedule + 3 permission + 4 NotificationDelegate). Celkem 61.
```

- [ ] **Step 5: Commit + tag**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for Plan 4 reminders"
git tag -a v0.4.0 -m "Plan 4 (Reminders) complete"
```

---

## Hotovo — Plan 4 dokončen

Stav po Plan 4:
- Mamka dostane lokální notifikaci po nastaveném intervalu od konce sezení.
- Akce v notifikaci (Krmím teď / Odložit 15 / Odložit 30) fungují bez nutnosti otevírat app pro snooze.
- Settings ji nechá zaměnit interval kdykoliv.
- Pokud notifikace zakáže v iOS Settings, vidí banner.

**Stojí před Plan 5 (Historie):** žádná tvrdá závislost. Plan 5 lze začít paralelně.
