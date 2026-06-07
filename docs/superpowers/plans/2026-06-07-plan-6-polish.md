# Kojení — Plan 6: Polish

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Doladit appku pro reálné nasazení na maminčině iPhonu. 6 cílených zlepšení adresujících technický dluh, spec edge cases, a reálné scénáře co Plan 1–5 odložily. Žádné nové funkce — jen kvalita stávajících.

**Architecture:** Žádné nové services ani významné architektonické změny. Sjednocuje error-handling pattern (centrální banner místo print), opraví drobné tech debts, doplní spec edge case (12h zapomenuté sezení dialog), refaktor identifikátorů, a accessibility první vrstva (VoiceOver labels). Pak finální tag v0.6.0 jako „připraveno na deploy".

**Tech Stack:** Beze změny vůči Plan 1–5. SwiftUI + SwiftData + Swift Testing.

> Plan navazuje na Plan 5 (cumulative 69 tests, tag v0.5.0). Žádný file overlap z paralelního Plan 4+5 už není problém — main je clean.

---

## Co řešíme (6 tasků)

1. **Centrální error banner** — `ErrorBanner` mechanism v RootView; nahradí `print("X failed: \(error)")` ve views/services. Banner se sám skryje po 5s.
2. **Sezení > 12h dialog** — spec sekce 5 edge case: pokud při startu app existuje aktivní sezení > 12h, ukázat „Zapomenuté sezení?" → [Uložit] / [Zrušit sezení].
3. **`StopFeedingIntent` identifiers refactor** — Plan 4 tech debt: duplikované string konstanty `"feeding-reminder"` / `"feeding-reminder-category"`. Extract do `Kojeni/SharedAttributes/NotificationIdentifiers.swift` (target membership Kojeni + KojeniWidgetExtension).
4. **Re-open PumpedMlSheet on app launch** — spec sekce 2 datový tok: pokud existuje ukončené sezení s `pumpedMl == nil` (force-quit mezi Stop a sheet save), ukázat PumpedMlSheet při příštím otevření.
5. **Accessibility VoiceOver labels** — průchod hlavními UI flows, doplnit `accessibilityLabel` / `accessibilityHint` / `accessibilityIdentifier` na klíčové buttony, headings, banner. Žádný plný WCAG audit — minimum viable pro mamku se sluchátkem.
6. **Smoke + CHANGELOG + tag v0.6.0**.

**Vědomě NEpatří do Plan 6:**
- Localizable.strings refactor (existující české literály fungují; refactor je čistě kosmetický).
- iPad layout / landscape.
- Apple Health export.
- Light/Dark mode design audit (nativně podporujeme přes SwiftUI defaults).
- Custom App Icon (Plan 1 nechal Xcode default).

---

## Task 1: Centrální `ErrorBanner` mechanism

**Files:**
- Create: `Kojeni/Kojeni/Services/ErrorReporter.swift`
- Create: `Kojeni/Kojeni/Features/Common/ErrorBannerOverlay.swift`
- Modify: `Kojeni/Kojeni/KojeniApp.swift` (inject reporter)
- Modify: `Kojeni/Kojeni/App/RootView.swift` (přidat overlay)
- Modify: ~6 view souborů co volaly `print("X failed")` (BreastPickerSheet, ActiveSessionView, IdleHomeView.logPee, PumpedMlSheet, DiaperSheet, OnboardingSheet, EditSessionSheet)

**Cíl:** `@Observable ErrorReporter` drží aktuální error message + timeout. Views místo `print` volají `errorReporter.report("Něco se pokazilo.")`. `ErrorBannerOverlay` v `RootView` zobrazí banner nahoře, sám se po 5s skryje. Žádné modální alerty — non-blocking.

- [ ] **Step 1: Vytvoř `ErrorReporter` + 2 unit testy**

`Kojeni/Kojeni/Services/ErrorReporter.swift`:

```swift
import Foundation
import SwiftUI

@MainActor
@Observable
final class ErrorReporter {

    /// Aktuálně zobrazená error message, `nil` pokud nic.
    private(set) var current: String?

    /// Auto-dismiss timeout v sekundách.
    var dismissAfter: TimeInterval = 5.0

    @ObservationIgnored
    private var dismissTask: Task<Void, Never>?

    /// Nahradí stávající message (pokud existuje) novou + naplánuje auto-dismiss.
    func report(_ message: String) {
        current = message
        dismissTask?.cancel()
        dismissTask = Task { [dismissAfter] in
            try? await Task.sleep(nanoseconds: UInt64(dismissAfter * 1_000_000_000))
            if !Task.isCancelled {
                current = nil
            }
        }
    }

    /// Manuální dismiss (uživatel tapne X na banneru).
    func dismiss() {
        current = nil
        dismissTask?.cancel()
        dismissTask = nil
    }
}
```

Test: `Kojeni/KojeniTests/Services/ErrorReporterTests.swift`:

```swift
import Testing
import Foundation
@testable import Kojeni

@Suite @MainActor
struct ErrorReporterTests {

    @Test func report_sets_current() {
        let r = ErrorReporter()
        r.report("Boom")
        #expect(r.current == "Boom")
    }

    @Test func dismiss_clears_current() {
        let r = ErrorReporter()
        r.report("Boom")
        r.dismiss()
        #expect(r.current == nil)
    }

    @Test func report_replaces_previous() {
        let r = ErrorReporter()
        r.report("First")
        r.report("Second")
        #expect(r.current == "Second")
    }
}
```

- [ ] **Step 2: Vytvoř `ErrorBannerOverlay`**

`Kojeni/Kojeni/Features/Common/ErrorBannerOverlay.swift`:

```swift
import SwiftUI

struct ErrorBannerOverlay: View {
    @Environment(ErrorReporter.self) private var reporter

    var body: some View {
        VStack {
            if let message = reporter.current {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    Button(action: { reporter.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(.red.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(duration: 0.3), value: reporter.current)
    }
}
```

- [ ] **Step 3: Inject `ErrorReporter` v `KojeniApp` a wire overlay v `RootView`**

V `KojeniApp.swift` přidej:

```swift
    @State private var errorReporter = ErrorReporter()
```

A do `.environment` chain v `body`:

```swift
                .environment(errorReporter)
```

V `RootView.swift` přidej do `body` jako last modifier (overlay na top):

```swift
        .overlay(alignment: .top) {
            ErrorBannerOverlay()
        }
```

A přidej `@Environment(ErrorReporter.self) private var errorReporter` do `RootView`.

- [ ] **Step 4: Nahraď `print(...)` ve views za `errorReporter.report(...)`**

V každém z těchto souborů přidej `@Environment(ErrorReporter.self) private var errorReporter` a nahraď `print("X failed: \(error)")` za `errorReporter.report("Něco se pokazilo, zkus znovu.")` nebo specifičtěji:

| Soubor | Místo | Nová zpráva |
|---|---|---|
| `BreastPickerSheet.swift` | `startSession failed` | `"Nepodařilo se spustit kojení."` |
| `ActiveSessionView.swift` | `switchBreast failed`, `endSession failed` | `"Nepodařilo se přepnout prso."`, `"Nepodařilo se ukončit sezení."` |
| `IdleHomeView.swift` | `logPee failed` | `"Nepodařilo se zaznamenat čůrání."` |
| `PumpedMlSheet.swift` | `save failed` | `"Nepodařilo se uložit ml."` |
| `DiaperSheet.swift` | `logPoo failed` | `"Nepodařilo se zaznamenat plenku."` |
| `OnboardingSheet.swift` | `save failed` | `"Nepodařilo se uložit nastavení."` |
| `EditSessionSheet.swift` | `save failed` | `"Nepodařilo se uložit změny."` |

- [ ] **Step 5: Update všechny `#Preview` se `ErrorReporter()`**

Tam kde view bere `@Environment(ErrorReporter.self)`, přidej do `#Preview`:

```swift
        .environment(ErrorReporter())
```

(Týká se: BreastPickerSheet, ActiveSessionView pokud má preview, IdleHomeView, HomeView, PumpedMlSheet pokud má preview, DiaperSheet, OnboardingSheet, EditSessionSheet, SettingsView)

- [ ] **Step 6: Build + tests**

Expected: 72 passed (69 + 3 nové ErrorReporter).

- [ ] **Step 7: Commit**

```bash
git add Kojeni/Kojeni/Services/ErrorReporter.swift \
        Kojeni/Kojeni/Features/Common \
        Kojeni/Kojeni/KojeniApp.swift \
        Kojeni/Kojeni/App/RootView.swift \
        Kojeni/Kojeni/Features \
        Kojeni/KojeniTests/Services/ErrorReporterTests.swift
git commit -m "feat(polish): central ErrorReporter + banner overlay, replace print calls in 7 views"
```

---

## Task 2: Sezení > 12h dialog

**Files:**
- Modify: `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift`
- Modify: `Kojeni/Kojeni/App/RootView.swift`

**Cíl:** Spec sekce 5/6 edge case: při startu app pokud existuje aktivní sezení s `startedAt < now - 12h`, ukázat `alert` „Zdá se, že kojení trvá X h. Bylo to opravdu tak dlouhé, nebo zapomněl/a Stop?" se 2 buttony [Uložit (Stop teď)] / [Zrušit sezení (delete)].

> Plan 3 už ukazuje banner > 8h v `ActiveSessionView`. Teď přidáváme **alert** při app launch — agresivnější UX, protože >12h pravděpodobně znamená zapomnuté.

- [ ] **Step 1: Logika detekce v `RootView`**

Do `RootView.swift` přidej do `@State`:

```swift
    @State private var forgottenSession: FeedingSession?
    @State private var showForgottenAlert = false
```

A v `handleInitialState()` přidej kontrolu:

```swift
        // Forgotten session detection (>12h active)
        let descriptor = FetchDescriptor<FeedingSession>(
            predicate: #Predicate { $0.endedAt == nil }
        )
        if let active = (try? modelContext.fetch(descriptor))?.first,
           Date.now.timeIntervalSince(active.startedAt) > 12 * 3600 {
            forgottenSession = active
            showForgottenAlert = true
        }
```

A v `body` přidej `.alert`:

```swift
        .alert("Zapomenuté sezení?",
               isPresented: $showForgottenAlert,
               presenting: forgottenSession) { session in
            Button("Uložit (Stop teď)") {
                stopForgottenSession(session)
            }
            Button("Zrušit sezení", role: .destructive) {
                deleteForgottenSession(session)
            }
        } message: { session in
            let hours = Int(Date.now.timeIntervalSince(session.startedAt) / 3600)
            Text("Zdá se, že kojení trvá \(hours) h. Bylo to opravdu tak dlouhé, nebo jsi zapomněla stopnout?")
        }
```

A pomocné metody:

```swift
    private func stopForgottenSession(_ session: FeedingSession) {
        do {
            _ = try FeedingService(context: modelContext).endSession()
            // PumpedMlSheet pickup se zařídí přes existing handleAppGroupPickup
        } catch {
            print("stopForgottenSession failed: \(error)")
        }
        forgottenSession = nil
    }

    private func deleteForgottenSession(_ session: FeedingSession) {
        modelContext.delete(session)
        try? modelContext.save()
        forgottenSession = nil
    }
```

- [ ] **Step 2: Test pro detekci (unit test — bez UI)**

`Kojeni/KojeniTests/Models/ForgottenSessionTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import Kojeni

@Suite @MainActor
struct ForgottenSessionTests {

    @Test func session_started_13h_ago_detected_as_forgotten() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        let s = FeedingSession(startedAt: Date.now.addingTimeInterval(-13 * 3600),
                                initialBreast: .left)
        context.insert(s)
        try context.save()

        let descriptor = FetchDescriptor<FeedingSession>(
            predicate: #Predicate { $0.endedAt == nil }
        )
        let active = try context.fetch(descriptor).first
        #expect(active != nil)
        let isForgotten = active.map {
            Date.now.timeIntervalSince($0.startedAt) > 12 * 3600
        } ?? false
        #expect(isForgotten == true)
    }

    @Test func session_started_2h_ago_not_detected() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        let s = FeedingSession(startedAt: Date.now.addingTimeInterval(-2 * 3600),
                                initialBreast: .left)
        context.insert(s)
        try context.save()

        let descriptor = FetchDescriptor<FeedingSession>(
            predicate: #Predicate { $0.endedAt == nil }
        )
        let active = try context.fetch(descriptor).first
        let isForgotten = active.map {
            Date.now.timeIntervalSince($0.startedAt) > 12 * 3600
        } ?? false
        #expect(isForgotten == false)
    }
}
```

- [ ] **Step 3: Build + tests**

Expected: 74 passed (72 + 2 nové).

- [ ] **Step 4: Commit**

```bash
git add Kojeni/Kojeni/App/RootView.swift \
        Kojeni/KojeniTests/Models/ForgottenSessionTests.swift
git commit -m "feat(ux): forgotten session dialog (>12h) on app launch — Save or Cancel"
```

---

## Task 3: `NotificationIdentifiers` shared constants

**Files:**
- Create: `Kojeni/Kojeni/SharedAttributes/NotificationIdentifiers.swift`
- Modify: `Kojeni/Kojeni/Services/ReminderScheduler.swift` (use shared constants)
- Modify: `Kojeni/Kojeni/AppIntents/StopFeedingIntent.swift` (use shared constants)
- Xcode UI: target membership

**Cíl:** Plan 4 tech debt: duplikované `"feeding-reminder"` / `"feeding-reminder-category"` mezi `ReminderScheduler` (main app target) a `StopFeedingIntent` (oba targety, ale bez ReminderScheduler dep). Extract do shared file v `SharedAttributes/`.

- [ ] **Step 1: Vytvoř shared file**

`Kojeni/Kojeni/SharedAttributes/NotificationIdentifiers.swift`:

```swift
import Foundation

/// Identifikátory lokálních notifikací sdílené mezi hlavní app a widget extension.
/// Stejně jako `AppGroup.identifier` — `nonisolated` aby App Intent
/// v non-MainActor kontextu mohl konstanty číst bez warning.
enum NotificationIdentifiers {
    nonisolated static let reminderRequest = "feeding-reminder"
    nonisolated static let reminderCategory = "feeding-reminder-category"
    nonisolated static let feedingNowAction = "feeding-now-action"
    nonisolated static let snooze15Action = "snooze-15-action"
    nonisolated static let snooze30Action = "snooze-30-action"
}
```

- [ ] **Step 2: Update `ReminderScheduler.swift`**

Nahraď:
- `static let notificationIdentifier = "feeding-reminder"` → odstraň (použij `NotificationIdentifiers.reminderRequest` na call sitech)
- `static let categoryIdentifier = "feeding-reminder-category"` → odstraň (use `NotificationIdentifiers.reminderCategory`)
- `static let feedingNowActionID = "feeding-now-action"` → odstraň
- `static let snooze15ActionID = "snooze-15-action"` → odstraň
- `static let snooze30ActionID = "snooze-30-action"` → odstraň

V `requestAuthorization()`, `scheduleAfter()`, `cancelPending()`, `registerCategory()`:
- `Self.notificationIdentifier` → `NotificationIdentifiers.reminderRequest`
- `Self.categoryIdentifier` → `NotificationIdentifiers.reminderCategory`
- `Self.feedingNowActionID` → `NotificationIdentifiers.feedingNowAction`
- atd.

V `NotificationDelegate.handleAction(identifier:)` switch:
- `case ReminderScheduler.feedingNowActionID:` → `case NotificationIdentifiers.feedingNowAction:`
- atd.

V `ReminderSchedulerTests.swift`:
- `ReminderScheduler.notificationIdentifier` → `NotificationIdentifiers.reminderRequest`
- `ReminderScheduler.categoryIdentifier` → `NotificationIdentifiers.reminderCategory`
- action IDs analogicky.

V `NotificationDelegateTests.swift`:
- `ReminderScheduler.feedingNowActionID` → `NotificationIdentifiers.feedingNowAction`
- atd.

- [ ] **Step 3: Update `StopFeedingIntent.swift`**

```swift
            content.categoryIdentifier = NotificationIdentifiers.reminderCategory
            // ...
            let request = UNNotificationRequest(
                identifier: NotificationIdentifiers.reminderRequest,
                content: content,
                trigger: trigger
            )
```

- [ ] **Step 4: Target membership pro `NotificationIdentifiers.swift`**

V Xcode → `KojeniWidgetExtension` target → Build Phases → Compile Sources → `+` → vybrat `NotificationIdentifiers.swift`.

> Stejný pattern jako Plan 3 Task 8 bulk membership.

- [ ] **Step 5: Build + tests**

Expected: 74 passed (žádný regress).

- [ ] **Step 6: Commit**

```bash
git add Kojeni/Kojeni/SharedAttributes/NotificationIdentifiers.swift \
        Kojeni/Kojeni/Services/ReminderScheduler.swift \
        Kojeni/Kojeni/Services/NotificationDelegate.swift \
        Kojeni/Kojeni/AppIntents/StopFeedingIntent.swift \
        Kojeni/KojeniTests/Services/ReminderSchedulerTests.swift \
        Kojeni/KojeniTests/Services/NotificationDelegateTests.swift \
        Kojeni/Kojeni.xcodeproj/project.pbxproj
git commit -m "refactor(notifications): extract NotificationIdentifiers to shared module"
```

---

## Task 4: Re-open PumpedMlSheet on app launch pokud chybí ml

**Files:**
- Modify: `Kojeni/Kojeni/App/RootView.swift`

**Cíl:** Spec sekce 2 datový tok: pokud user force-quit appku mezi Stop a save ml, sezení má `endedAt != nil && pumpedMl == nil`. Při příštím spuštění by mělo PumpedMlSheet znovu vyskočit. Plan 3 Task 10 řeší pickup z App Intent path (StopFeedingIntent flag) ale ne tuto path.

> Pickup logic existuje v `handleAppGroupPickup()`. Rozšíříme detekci: i bez flagu zkontrolujeme „nejnovější sezení s endedAt != nil && pumpedMl == nil && endedAt > now - 24h" (24h cutoff aby starší zapomenuté sezení neotravovaly).

- [ ] **Step 1: Rozšiř `handleAppGroupPickup` v `RootView.swift`**

Po existující `pendingPumpedMlSheet` logice přidej fallback path:

```swift
    private func handleAppGroupPickup() {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)

        // Path A: pickup přes UserDefaults flag (StopFeedingIntent path)
        if defaults?.bool(forKey: "pendingStartFromReminder") == true {
            defaults?.set(false, forKey: "pendingStartFromReminder")
            startFromReminder()
        }

        if defaults?.bool(forKey: "pendingPumpedMlSheet") == true {
            defaults?.set(false, forKey: "pendingPumpedMlSheet")
            handleStoredPickup(defaults: defaults)
            return  // sheet už otevřený, nedělej fallback
        }

        // Path B: fallback — orphaned ended session bez ml (in-app Stop + force-quit)
        let descriptor = FetchDescriptor<FeedingSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let candidates = (try? modelContext.fetch(descriptor)) ?? []
        let twentyFourHoursAgo = Date.now.addingTimeInterval(-24 * 3600)
        let orphan = candidates.first { session in
            guard let endedAt = session.endedAt else { return false }
            return endedAt > twentyFourHoursAgo && session.pumpedMl == nil
        }
        if let orphan {
            pumpedMlPickupSessionID = orphan.persistentModelID
            showPickupSheet = true
        }
    }

    private func handleStoredPickup(defaults: UserDefaults?) {
        let endedAtRaw = defaults?.double(forKey: "pendingPumpedMlSheet.endedAt") ?? 0
        guard endedAtRaw > 0 else { return }
        let target = Date(timeIntervalSinceReferenceDate: endedAtRaw)
        let descriptor = FetchDescriptor<FeedingSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let candidates = (try? modelContext.fetch(descriptor)) ?? []
        let candidate = candidates.first { session in
            guard let endedAt = session.endedAt else { return false }
            return abs(endedAt.timeIntervalSince(target)) < 5.0 && session.pumpedMl == nil
        }
        if let candidate {
            pumpedMlPickupSessionID = candidate.persistentModelID
            showPickupSheet = true
        }
    }
```

> Funkčně: pokud user explicitně skipne ml v PumpedMlSheet (nastaví `pumpedMl = nil`), sheet se otevře znovu při příštím launchi. Aby to nebylo otravné, **PumpedMlSheet skip cesta musí sezení označit jiným způsobem**. Plan 6 doplní: PumpedMlSheet Skip nastaví `pumpedMl = -1` (sentinel pro „explicitly skipped").

- [ ] **Step 2: Update `PumpedMlSheet.skip()` aby použila sentinel**

V `Kojeni/Kojeni/Features/PostFeed/PumpedMlSheet.swift`:

```swift
    private func skip() {
        do {
            if let session = modelContext.model(for: sessionID) as? FeedingSession {
                // Sentinel: -1 znamená „uživatel explicitně přeskočil",
                // aby fallback re-open logika v RootView ho už nepicknula.
                session.pumpedMl = -1
                try modelContext.save()
            }
        } catch {
            print("PumpedMlSheet skip-mark failed: \(error)")
        }
        dismiss()
    }
```

- [ ] **Step 3: Update `EditSessionSheet` UI aby -1 zacházel jako „přeskočeno"**

V `EditSessionSheet.init`:

```swift
        _hasPumpedMl = State(initialValue: session.pumpedMl != nil && session.pumpedMl != -1)
        _pumpedMl = State(initialValue: (session.pumpedMl ?? 0) < 0 ? 0 : (session.pumpedMl ?? 0))
```

V `save()` zmen:
```swift
        session.pumpedMl = hasPumpedMl ? pumpedMl : -1
```

(`-1` místo `nil` aby fallback pickup věděl že to bylo explicit skip.)

- [ ] **Step 4: Test pro orphan detection**

`Kojeni/KojeniTests/Models/OrphanedSessionTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import Kojeni

@Suite @MainActor
struct OrphanedSessionTests {

    @Test func ended_session_without_pumpedMl_is_orphan() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        let s = FeedingSession(startedAt: Date.now.addingTimeInterval(-3600), initialBreast: .left)
        s.endedAt = Date.now.addingTimeInterval(-1800)   // skončilo před 30 min
        // pumpedMl zůstává nil
        context.insert(s)
        try context.save()

        let descriptor = FetchDescriptor<FeedingSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let candidates = try context.fetch(descriptor)
        let cutoff = Date.now.addingTimeInterval(-24 * 3600)
        let orphan = candidates.first { session in
            guard let endedAt = session.endedAt else { return false }
            return endedAt > cutoff && session.pumpedMl == nil
        }
        #expect(orphan != nil)
    }

    @Test func ended_session_with_sentinel_minusOne_is_not_orphan() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        let s = FeedingSession(startedAt: Date.now.addingTimeInterval(-3600), initialBreast: .left)
        s.endedAt = Date.now.addingTimeInterval(-1800)
        s.pumpedMl = -1   // explicitly skipped
        context.insert(s)
        try context.save()

        let descriptor = FetchDescriptor<FeedingSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let candidates = try context.fetch(descriptor)
        let cutoff = Date.now.addingTimeInterval(-24 * 3600)
        let orphan = candidates.first { session in
            guard let endedAt = session.endedAt else { return false }
            return endedAt > cutoff && session.pumpedMl == nil
        }
        #expect(orphan == nil)   // -1 není nil → not orphan
    }

    @Test func ended_session_older_than_24h_not_orphan() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        let s = FeedingSession(startedAt: Date.now.addingTimeInterval(-48 * 3600),
                                initialBreast: .left)
        s.endedAt = Date.now.addingTimeInterval(-47 * 3600)
        context.insert(s)
        try context.save()

        let descriptor = FetchDescriptor<FeedingSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let candidates = try context.fetch(descriptor)
        let cutoff = Date.now.addingTimeInterval(-24 * 3600)
        let orphan = candidates.first { session in
            guard let endedAt = session.endedAt else { return false }
            return endedAt > cutoff && session.pumpedMl == nil
        }
        #expect(orphan == nil)
    }
}
```

- [ ] **Step 5: Build + tests**

Expected: 77 passed (74 + 3 nové orphan).

- [ ] **Step 6: Commit**

```bash
git add Kojeni/Kojeni/App/RootView.swift \
        Kojeni/Kojeni/Features/PostFeed/PumpedMlSheet.swift \
        Kojeni/Kojeni/Features/History/EditSessionSheet.swift \
        Kojeni/KojeniTests/Models/OrphanedSessionTests.swift
git commit -m "feat(ux): re-open PumpedMlSheet on launch for orphaned sessions (<24h, no ml)

Sentinel pumpedMl=-1 marks 'explicitly skipped' so the sheet doesn't
re-open after user skips. EditSessionSheet handles the sentinel as
'no value' in the toggle."
```

---

## Task 5: Accessibility VoiceOver labels — minimum viable

**Files:**
- Modify: `Kojeni/Kojeni/Features/Home/IdleHomeView.swift`
- Modify: `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift`
- Modify: `Kojeni/Kojeni/Features/Home/BreastPickerSheet.swift`
- Modify: `Kojeni/Kojeni/Features/PostFeed/PumpedMlSheet.swift`
- Modify: `Kojeni/Kojeni/Features/PostFeed/DiaperSheet.swift`
- Modify: `Kojeni/Kojeni/Features/Common/ErrorBannerOverlay.swift`

**Cíl:** Hlavní action buttons mají `.accessibilityLabel` (smysluplný popis) + `.accessibilityHint` (co se stane po tapu) pokud není zřejmé. Banner se anuncuje VoiceOverem (`.accessibilityAddTraits(.isModal)`). Timer text v ActiveSessionView má semantic label „Délka aktuálního kojení".

> Žádný plný WCAG audit — jen polish hlavní cesty. Plánujeme to víc jako konkrétní user feedback.

- [ ] **Step 1: IdleHomeView**

Na velký Kojit button přidej:
```swift
            Button(action: { showBreastPicker = true }) { ... }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .accessibilityLabel("Spustit nové kojení")
                .accessibilityHint("Otevře výběr prsa")
```

Na Čůrání button:
```swift
                Button(action: logPee) { ... }
                    .accessibilityLabel("Zaznamenat čůrání")
```

Na Kakání button:
```swift
                Button(action: { showDiaperSheet = true }) { ... }
                    .accessibilityLabel("Zaznamenat kakání")
                    .accessibilityHint("Otevře výběr konzistence")
```

Na permissionBanner (pokud existuje) přidej:
```swift
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
```

Na lastFeedingHeader pokud existuje:
```swift
            .accessibilityLabel("Poslední kojení skončilo \(relativeTimeString)")
```

(kde `relativeTimeString` je kompoze textů na header — můžeš nahradit dynamickým formatovaným stringem.)

- [ ] **Step 2: ActiveSessionView**

Na timer Text přidej:
```swift
            Text(timerInterval: session.startedAt...Date.distantFuture, countsDown: false)
                .font(...)
                .monospacedDigit()
                .accessibilityLabel("Délka kojení")
                .accessibilityValue("\(Int(session.duration / 60)) minut")
```

Na Přehodit prso:
```swift
                Button(action: switchBreast) { ... }
                    .accessibilityLabel("Přehodit na opačné prso")
                    .accessibilityHint("Aktuálně je \(label(for: session.currentBreast)) prso")
```

Na Stop:
```swift
                Button(role: .destructive, action: endSession) { ... }
                    .accessibilityLabel("Ukončit kojení")
                    .accessibilityHint("Otevře dialog pro zadání odstříkaného mléka")
```

- [ ] **Step 3: BreastPickerSheet**

Na Levé / Pravé buttons (uvnitř `breastButton(for:)`):
```swift
        Button(action: { start(with: breast) }) { label }
            .buttonStyle(...)
            .controlSize(.large)
            .accessibilityLabel(self.accessibilityLabel(for: breast))
            .accessibilityHint(suggestedBreast == breast ? "Doporučeno" : "")
```

A přidat helper:
```swift
    private func accessibilityLabel(for breast: Breast) -> String {
        switch breast {
        case .left:  return "Začít kojení levým prsem"
        case .right: return "Začít kojení pravým prsem"
        }
    }
```

- [ ] **Step 4: PumpedMlSheet + DiaperSheet**

PumpedMlSheet — na Stepper přidej:
```swift
            Stepper(value: $ml, in: 0...300, step: 5) { ... }
                .accessibilityLabel("Odstříkané mléko")
                .accessibilityValue("\(ml) mililitrů")
```

Na Uložit / Přeskočit buttons:
```swift
                Button(action: save) { Text("Uložit") ... }
                    .accessibilityHint("Zapíše \(ml) ml a zavře dialog")

                Button(action: skip) { Text("Přeskočit") ... }
                    .accessibilityHint("Zavře dialog bez záznamu")
```

DiaperSheet — na 3 consistency buttons:
```swift
        Button(action: { log(consistency: consistency) }) { ... }
            .accessibilityLabel("Konzistence: \(label)")
```

- [ ] **Step 5: ErrorBannerOverlay**

```swift
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits([.isModal, .isLiveRegion])
                .accessibilityLabel("Chyba: \(message)")
```

- [ ] **Step 6: Build + tests**

Expected: 77 passed (žádný regress).

- [ ] **Step 7: Commit**

```bash
git add Kojeni/Kojeni/Features
git commit -m "feat(a11y): VoiceOver labels + hints on main actions (Idle/Active/Pickers/Sheets)"
```

---

## Task 6: E2E smoke + CHANGELOG + tag v0.6.0

**Files:** `CHANGELOG.md`

**Cíl:** Finální verifikace polish bodů + tag.

- [ ] **Step 1: Build + full test run**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination 'platform=iOS Simulator,id=8642F9E0-4452-421F-AFA1-DD31D947F658' \
  -parallel-testing-enabled NO 2>&1 | tail -10
```

Expected: 77 tests passed, TEST SUCCEEDED.

- [ ] **Step 2: Manual smoke (Simulator.app — ⌘L pro Lock Screen, ⇧⌘H pro background)**

- [ ] Erase simulator + clean install + onboarding s permission grant.
- [ ] Vytvořit chybu (např. otočit `Schema` v KojeniApp dočasně) → vidět error banner → opravit zpátky.
- [ ] (Plan 4 reminder flow už ověřený dříve.)
- [ ] Force-quit appky mezi Stop a PumpedMlSheet → relaunch → PumpedMlSheet se objeví automaticky pro orphan session.
- [ ] PumpedMlSheet Přeskočit → relaunch → sheet se **NE**objeví znovu.
- [ ] Spustit sezení, čekat 12h+ (nebo manipulovat `startedAt` přímo přes EditSessionSheet) → relaunch → alert „Zapomenuté sezení?".
- [ ] Zapnout VoiceOver (`Settings → Accessibility → VoiceOver`) → projít hlavní obrazovkou → ověřit smysluplné labels.

- [ ] **Step 3: Update `CHANGELOG.md`**

Před `## [0.5.0]` přidej:

```markdown
## [0.6.0] — Plan 6: Polish — 2026-06-07

- `ErrorReporter` + `ErrorBannerOverlay` — centrální non-blocking error UI namísto `print` v 7 views.
- Forgotten session dialog (>12h aktivní při app launch) → Save (Stop teď) / Cancel (delete).
- `NotificationIdentifiers` shared module — refactor Plan 4 duplikovaných string konstant.
- Re-open PumpedMlSheet při app launch pro orphaned session (endedAt != nil, pumpedMl == nil, <24h). Sentinel `pumpedMl = -1` označuje explicitní skip.
- VoiceOver labels + hints na hlavních akcích (Idle/Active/Pickers/Sheets/Banner).
- 8 nových Swift Testing testů (3 ErrorReporter + 2 ForgottenSession + 3 OrphanedSession). Celkem 77.
```

- [ ] **Step 4: Commit + tag**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for Plan 6 polish"
git tag -a v0.6.0 -m "Plan 6 (Polish) — ready for AltStore deploy

Spec section 8 DoD checklist:
- All 6 functional scope items implemented (v0.1-v0.5)
- 77 unit tests on Models + Services, all green
- No known crashes
- Forgotten session edge case handled
- Orphaned session pickup handled
- Error surface unified (no silent print failures)
- A11y first pass on main flows
"
```

---

## Hotovo — Plan 6 dokončen

Stav po Plan 6 a v0.6.0:
- Spec sekce 8 Definition of Done je splněná (až na fyzický deploy na maminčiným iPhone).
- App je připravena k AltStore re-signu + instalaci.
- Reálný feedback od maminky → Plan 7 (pokud bude potřeba).
