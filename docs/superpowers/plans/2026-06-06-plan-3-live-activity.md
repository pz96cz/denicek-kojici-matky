# Kojení — Plan 3: Live Activity

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Funkční Live Activity pro kojení — viditelný timer na Lock Screen + Dynamic Island, dvě interaktivní tlačítka („Přehodit prso", „Stop") bez nutnosti odemykat telefon u Přehodit; Stop otevře hlavní app na PumpedMlSheet. Po dokončení plánu mamka může celé sezení odbavit s telefonem zamčeným kromě poslední fáze (ml zadání).

**Architecture:** Druhý Xcode target (Widget Extension) sdílí kód přes shared file membership + App Group entitlement (sdílený SwiftData store). Spec sekce 5: Live Activity ID žije pouze v paměti `LiveActivityManager`; re-attach při restartu přes `Activity<FeedingAttributes>.activities`. FeedingService z Plan 2 zůstává **beze změny** — Live Activity orchestrace se přidá na call-sitech (UI views + App Intents). `SwitchBreastIntent` = `LiveActivityIntent` (běží v Widget procesu, žádné odemčení). `StopFeedingIntent` = `AppIntent` s `openAppWhenRun = true` (otevře app pro PumpedMlSheet).

**Tech Stack:** Swift 6+, Xcode 26+, iOS 26.5+, SwiftUI, SwiftData, **ActivityKit**, **WidgetKit**, **App Intents**, Swift Testing. Žádné externí dependency.

---

## Riziko a fallbacky

### App Group entitlement na free Apple ID + AltStore

Live Activity App Intent v Widget procesu potřebuje **App Group entitlement**, aby mohl číst/psát do téhož SwiftData store jako hlavní app. Xcode generuje App Group automaticky pro Personal Team developery — Apple to v posledních letech rozšířil. AltStore při re-signu entitlement zachová (re-mapuje team prefix). **Měl by fungovat**, ale ne se 100% jistotou.

**Fallback pokud App Group selže:** Zúžit `SwitchBreastIntent` aby použila `openAppWhenRun = true` jako `StopFeedingIntent`. Mamka musí odemknout telefon pro Switch. Spec nedodržíme, ale appka pojede. Tento fallback NEpíšeme dopředu — řešíme až pokud reálné nasazení selže.

### Cross-process SwiftData @Query reaktivita

Widget proces zapíše `BreastChange` (přes `switchBreast()` v App Intentu). Hlavní app je v pozadí — její `@Query` v `ActiveSessionView` se nepřebije automaticky (SwiftData cross-process change notifikace pro local-only store není garantovaná). Důsledek: pokud mamka tapne Switch z Lock Screen, otevře app — `currentBreast` v HomeView může být stale.

**Mitigace:** Live Activity SAMA aktualizuje (přes `activity.update`). Hlavní app refreshne stav při `scenePhase` přechodu na `.active` přes explicit `modelContext.processPendingChanges()` (Task 10).

### Limited unit testing

Plan 1+2 mělo 42 testů. Plan 3 přidá <10 — `FeedingAttributes` Codable round-trip + `LiveActivityManager` "no-op when activities disabled" path. Vlastní Live Activity rendering, App Intent execution z widget procesu, cross-process invarianty se testují **manuálně na simulátoru a fyzickém zařízení**. Akceptováno.

---

## File Structure (po dokončení Plan 3)

```
kojeni-app/
└── Kojeni/                                      ← Xcode wrapper
    ├── Kojeni.xcodeproj/
    ├── Kojeni/                                  ← main App target
    │   ├── KojeniApp.swift                      ← MODIFY: ModelContainer s App Group + LA env injection
    │   ├── App/
    │   │   └── RootView.swift                   ← MODIFY: re-attach LA na .task
    │   ├── Models/                              ← (beze změny)
    │   ├── Services/
    │   │   ├── FeedingService.swift             ← (beze změny — to je důvod proč coordinator-less)
    │   │   ├── FeedingServiceError.swift        ← (beze změny)
    │   │   ├── DiaperService.swift              ← (beze změny)
    │   │   └── LiveActivityManager.swift        ← NEW
    │   ├── SharedAttributes/                    ← NEW složka
    │   │   └── FeedingAttributes.swift          ← NEW (shared file: target membership Kojeni + KojeniWidget)
    │   ├── AppIntents/                          ← NEW složka
    │   │   ├── SwitchBreastIntent.swift         ← NEW (LiveActivityIntent — v Widget procesu)
    │   │   └── StopFeedingIntent.swift          ← NEW (AppIntent openAppWhenRun)
    │   └── Features/
    │       ├── Home/
    │       │   ├── HomeView.swift               ← (beze změny)
    │       │   ├── IdleHomeView.swift           ← (beze změny)
    │       │   ├── ActiveSessionView.swift      ← MODIFY: wire LA update on switch, banner pro 8h overflow
    │       │   └── BreastPickerSheet.swift      ← MODIFY: wire LA start po startSession
    │       └── PostFeed/                        ← (beze změny)
    ├── KojeniWidget/                            ← NEW target (Plan 3 Task 1)
    │   ├── KojeniWidgetBundle.swift             ← NEW
    │   ├── FeedingLiveActivity.swift            ← NEW (Lock Screen + Dynamic Island widget views)
    │   └── Info.plist                           ← Widget target plist (auto-generated)
    └── KojeniTests/
        ├── Models/                              ← (beze změny)
        ├── Services/
        │   ├── FeedingServiceTests.swift        ← (beze změny)
        │   ├── DiaperServiceTests.swift         ← (beze změny)
        │   └── LiveActivityManagerTests.swift   ← NEW (interface contract — limited)
        ├── SharedAttributes/                    ← NEW složka
        │   └── FeedingAttributesTests.swift     ← NEW (Codable round-trip)
        └── Helpers/InMemoryContainer.swift      ← (beze změny)
```

**Vědomě NEpatří do Plan 3:**
- Reminders / lokální notifikace (Plan 4).
- Historie a editace sezení (Plan 5).
- Banner pro "notifikace zakázané" / "App Group failed" (Plan 6 polish).
- Migrace existujícího Plan 1/2 SwiftData store na App Group container (přijatelné dropování dev dat).
- Multi-process @Query auto-refresh (akceptujeme stale on background, refresh on .active scenePhase).

---

## Pre-Task: Bump tag a clean baseline

- [ ] Ověř že jsi na `main` s tagem `v0.2.0` (`git tag --list -n1 v0.2.0`). Plan 3 navazuje. Pokud Xcode má otevřený projekt, `⌘ Q` — některé tasky upravují pbxproj/entitlements a chceme čistý disk.

---

## Task 1: Přidat Widget Extension target

**Files:** `Kojeni/Kojeni.xcodeproj/project.pbxproj` (Xcode UI generated), `Kojeni/KojeniWidget/*` (boilerplate)

**Cíl:** Nový target `KojeniWidget` typu Widget Extension s šablonovým Live Activity kódem. Sestaví se prázdný widget bundle.

> Tento task vyžaduje Xcode UI. Implementer (subagent ani CLI) ho udělat nemůže — uživatel musí proklikat New Target wizard.

> **Naming poznámka (Xcode 26 reality):** Xcode si target název rozšíří na `KojeniWidgetExtension` (přidá „Extension" suffix), složka na disku zůstane `KojeniWidget/`. Všechny následné odkazy v tomto plánu na „target KojeniWidget" znamenají **target `KojeniWidgetExtension`**. Bundle ID bude `cz.zapletal.Kojeni.KojeniWidgetExtension`. Entitlement soubor (Task 2) Xcode pojmenuje `KojeniWidgetExtension.entitlements`. Xcode 26 také přidá do šablony `KojeniWidgetControl.swift` (Control Center widget) — Task 7 ho smaže spolu s `KojeniWidget.swift`.

- [ ] **Step 1: V Xcode otevři projekt**

```bash
open /Users/pz/Documents/develop/kojeni-app/Kojeni/Kojeni.xcodeproj
```

- [ ] **Step 2: New Target wizard**

`File` → `New` → `Target…` → záložka **iOS** → sekce **Application Extension** → vyber **Widget Extension** → `Next`.

Vyplň:
- **Product Name:** `KojeniWidget`
- **Team:** tvůj Personal Team (stejný jako Kojeni)
- **Bundle Identifier:** `cz.zapletal.Kojeni.KojeniWidget` (auto-derived)
- **Include Live Activity:** **☑ zaškrtnuto** ← kritické
- **Include Configuration Intent:** **☐ odznačit** (configuration intent nepotřebujeme — Live Activity Attributes nejsou configurable)
- **Embed in Application:** `Kojeni`

`Finish`. Když Xcode nabídne „Activate KojeniWidget scheme", odmítni — zůstaneme na Kojeni scheme.

- [ ] **Step 3: Ověř strukturu na disku**

```bash
find /Users/pz/Documents/develop/kojeni-app/Kojeni/KojeniWidget -type f | sort
```

Expected (přesné názvy mohou v Xcode 26 lehce kolísat):
- `KojeniWidget/KojeniWidget.swift` — šablonový Widget timeline (NEpotřebujeme — smaž v Task 7, zatím ho nech)
- `KojeniWidget/KojeniWidgetBundle.swift` — `@main` widget bundle
- `KojeniWidget/KojeniWidgetLiveActivity.swift` — šablonová Live Activity
- `KojeniWidget/Info.plist` — widget target plist
- `KojeniWidget/Assets.xcassets/` — placeholder assets

Pokud něco z toho chybí, smaž celý `KojeniWidget/` adresář na disku a opakuj Step 2.

- [ ] **Step 4: Ověř build**

V Xcode horní liště přepni scheme na `Kojeni`, vyber simulátor iPhone 17 Pro / iOS 26.5, **⌘ B**.

Expected: `Build Succeeded`. Šablonový widget se přibalí do main app jako extension.

> Pokud build hlásí chyby v `KojeniWidgetLiveActivity.swift` (např. typové konflikty se starou Attribute strukturou) — to je OK, Task 7 ho přepíše. Pro Plan 3 Task 1 stačí že main app + widget bundle se zkompilují bez fatalní chyby. Pokud opravdu fatal error blokuje build, smaž obsah `KojeniWidgetLiveActivity.swift` ručně a nahraď za:
> ```swift
> import WidgetKit
> import SwiftUI
> // Bude přepsáno v Task 7.
> ```

- [ ] **Step 5: Commit**

```bash
cd /Users/pz/Documents/develop/kojeni-app
git add Kojeni/KojeniWidget Kojeni/Kojeni.xcodeproj/project.pbxproj
git status
git commit -m "chore(widget): add KojeniWidget extension target (template, Live Activity-enabled)"
```

Expected: 1 commit s novým targetem, ~6 souborů.

---

## Task 2: App Group entitlement na obou targetech

**Files:** `Kojeni/Kojeni.xcodeproj/project.pbxproj`, `Kojeni/Kojeni/Kojeni.entitlements` (NEW), `Kojeni/KojeniWidget/KojeniWidget.entitlements` (NEW)

**Cíl:** Oba targety mají v entitlements `com.apple.security.application-groups = ["group.cz.zapletal.kojeni"]`. Xcode propíše App Group ID do provisioning profile.

> Vyžaduje Xcode UI.

- [ ] **Step 1: Přidat App Group capability na Kojeni target**

V Xcode levém navigátoru klikni na projekt **Kojeni** → vyber target **Kojeni** → záložka **Signing & Capabilities** → tlačítko `+ Capability` → vyhledej **App Groups** → double-click.

V přidané sekci **App Groups** klikni na `+` pod listem → vlož identifier:

```
group.cz.zapletal.kojeni
```

Xcode automaticky vyrobí `Kojeni/Kojeni/Kojeni.entitlements` soubor.

Pokud Xcode ohlási „signing requires development team" nebo červený ✖ vedle App Group:
- Refresh provisioning profile: záložka **Signing & Capabilities** → klikni `Try Again` u podpisu.
- Pokud stále selhává, je to free Apple ID limit (viz [Riziko](#riziko-a-fallbacky)). **STOP a eskaluj** uživateli.

- [ ] **Step 2: Přidat App Group capability na KojeniWidget target**

Vyber target **KojeniWidget** → záložka **Signing & Capabilities** → `+ Capability` → **App Groups** → přidej **stejný** identifier:

```
group.cz.zapletal.kojeni
```

Xcode vyrobí `Kojeni/KojeniWidget/KojeniWidget.entitlements`.

- [ ] **Step 3: Ověř entitlements soubory na disku**

```bash
cat /Users/pz/Documents/develop/kojeni-app/Kojeni/Kojeni/Kojeni.entitlements
cat /Users/pz/Documents/develop/kojeni-app/Kojeni/KojeniWidget/KojeniWidget.entitlements
```

Expected obsah obou:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.cz.zapletal.kojeni</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 4: Build check**

V Xcode **⌘ B**. Expected: `Build Succeeded`.

Pokud `Build Failed` s „Provisioning profile doesn't include the com.apple.security.application-groups entitlement":
- V Xcode `Product → Clean Build Folder` (⇧⌘K).
- V projekt navigátoru: target Kojeni → `Signing & Capabilities` → odznač **Automatically manage signing** → znovu zaškrtni → `Try Again`. To donutí Xcode přegenerovat profile s novými entitlements.
- Pokud stále failed, pravděpodobně narážíme na free Apple ID strop. STOP a eskaluj.

- [ ] **Step 5: Commit**

```bash
cd /Users/pz/Documents/develop/kojeni-app
git add Kojeni/Kojeni/Kojeni.entitlements \
        Kojeni/KojeniWidget/KojeniWidget.entitlements \
        Kojeni/Kojeni.xcodeproj/project.pbxproj
git commit -m "chore(entitlements): App Group group.cz.zapletal.kojeni on both targets"
```

---

## Task 3: Přesunout ModelContainer na App Group storage

**Files:** `Kojeni/Kojeni/KojeniApp.swift`

**Cíl:** Hlavní app teď používá `ModelConfiguration(groupContainer: .identifier("group.cz.zapletal.kojeni"))`, aby SQLite store žil ve sdílené App Group sandbox. Dropujeme dosavadní dev data (akceptovaná migrace).

- [ ] **Step 1: Erase simulator (smaže starý sandbox store)**

```bash
SIMCTL=/Applications/Xcode.app/Contents/Developer/usr/bin/simctl
SIM_ID=E7D54495-1FBF-4E65-B7E4-F55D51806898
$SIMCTL shutdown $SIM_ID 2>/dev/null
$SIMCTL erase $SIM_ID
$SIMCTL boot $SIM_ID
```

- [ ] **Step 2: Update `KojeniApp.swift`**

Otevři `Kojeni/Kojeni/KojeniApp.swift` a nahraď tělo `container` builder:

```swift
import SwiftUI
import SwiftData

@main
struct KojeniApp: App {

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
            groupContainer: .identifier("group.cz.zapletal.kojeni")
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
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 3: Build + run, ověř že app naběhne a onboarding ukáže**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath /tmp/kojeni-build -quiet 2>&1 | tail -5
$SIMCTL install $SIM_ID /tmp/kojeni-build/Build/Products/Debug-iphonesimulator/Kojeni.app
$SIMCTL launch $SIM_ID cz.zapletal.Kojeni
sleep 3
$SIMCTL io $SIM_ID screenshot /tmp/kojeni-task3-appgroup.png
```

Otevři screenshot — měl bys vidět OnboardingSheet (čistý sandbox, žádné AppSettings).

- [ ] **Step 4: Unit testy**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -quiet 2>&1 | grep -c "passed"
```

Expected: **42 passed** (testy běží proti in-memory containerům, App Group změna se jich netýká).

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/KojeniApp.swift
git commit -m "feat(app): move ModelContainer to App Group storage (shared with widget)"
```

---

## Task 4: `FeedingAttributes` (sdílený soubor)

**Files:**
- Create: `Kojeni/Kojeni/SharedAttributes/FeedingAttributes.swift`
- Create: `Kojeni/KojeniTests/SharedAttributes/FeedingAttributesTests.swift`

**Cíl:** `ActivityAttributes` struktura definující statickou metadata (sessionID, startedAt) a `ContentState` s dynamickými poli (currentBreast). Soubor musí být v target membership **obou** targetů (Kojeni i KojeniWidget) — Plan 1 měl synchronized folder reference jen pro main app source, takže pro tento soubor musíme target membership nastavit ručně přes File Inspector.

- [ ] **Step 1: Napiš failing test**

`Kojeni/KojeniTests/SharedAttributes/FeedingAttributesTests.swift`:

```swift
import Testing
import Foundation
@testable import Kojeni

@Suite
struct FeedingAttributesTests {

    @Test func encodes_and_decodes_attributes() throws {
        let originalAttrs = FeedingAttributes(
            sessionID: "ABC-123",
            sessionStartedAt: Date(timeIntervalSinceReferenceDate: 50000)
        )
        let encoded = try JSONEncoder().encode(originalAttrs)
        let decoded = try JSONDecoder().decode(FeedingAttributes.self, from: encoded)

        #expect(decoded.sessionID == "ABC-123")
        #expect(decoded.sessionStartedAt == originalAttrs.sessionStartedAt)
    }

    @Test func encodes_and_decodes_content_state() throws {
        let original = FeedingAttributes.ContentState(currentBreast: .right)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FeedingAttributes.ContentState.self, from: encoded)

        #expect(decoded.currentBreast == .right)
    }

    @Test func content_state_equality() {
        let a = FeedingAttributes.ContentState(currentBreast: .left)
        let b = FeedingAttributes.ContentState(currentBreast: .left)
        let c = FeedingAttributes.ContentState(currentBreast: .right)
        #expect(a == b)
        #expect(a != c)
    }
}
```

- [ ] **Step 2: Pusť testy — selžou**

Expected: `Cannot find 'FeedingAttributes' in scope`.

- [ ] **Step 3: Implementuj `FeedingAttributes`**

Vytvoř adresář a soubor:

```bash
mkdir -p /Users/pz/Documents/develop/kojeni-app/Kojeni/Kojeni/SharedAttributes
```

`Kojeni/Kojeni/SharedAttributes/FeedingAttributes.swift`:

```swift
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
```

- [ ] **Step 4: Target membership pro `FeedingAttributes.swift`**

V Xcode levém navigátoru klikni na nově vytvořený `FeedingAttributes.swift` → pravý File Inspector → sekce **Target Membership** → zaškrtni **OBA**:
- ☑ Kojeni
- ☑ KojeniWidget

> Synchronized folder reference (Plan 1) by mělo přidat soubor do Kojeni targetu automaticky, ale pro KojeniWidget je třeba explicitně zaškrtnout. Pokud to z nějakého důvodu nezafunguje (oba checkboxy zašedlé), použij `File → Add Files to "Kojeni"…` a v dialogu zaškrtni oba targety.

- [ ] **Step 5: Pusť testy — projdou**

Expected: **45 passed** (42 + 3 nové FeedingAttributes testy).

- [ ] **Step 6: Commit**

```bash
git add Kojeni/Kojeni/SharedAttributes \
        Kojeni/KojeniTests/SharedAttributes \
        Kojeni/Kojeni.xcodeproj/project.pbxproj
git commit -m "feat(activity): FeedingAttributes (shared between app + widget)"
```

---

## Task 5: `LiveActivityManager` service

**Files:**
- Create: `Kojeni/Kojeni/Services/LiveActivityManager.swift`
- Create: `Kojeni/KojeniTests/Services/LiveActivityManagerTests.swift`

**Cíl:** `@MainActor` service obalující `Activity<FeedingAttributes>` API. Drží referenci na běžící aktivitu v paměti. Při inicializaci se zkusí re-attachnout na existující aktivitu (po restartu appky). Metody `start(session:)`, `update(currentBreast:)`, `end()` jsou bezpečné no-op když `ActivityAuthorizationInfo().areActivitiesEnabled == false`.

- [ ] **Step 1: Napiš failing testy**

> Plnou Activity API testovat z unit testů nejde. Otestujeme dvě věci:
> 1. Při `init()` na cleanu (žádná aktivní LA) je `currentActivity == nil`.
> 2. Když `areActivitiesEnabled == false`, `start(session:)` nepoškodí stav (no-op, zůstane `currentActivity == nil`). Tohle nemůžeme přímo simulovat (no way to fake areActivitiesEnabled), tak vyrobíme test na cestě „start zavolán se sessionou ale activities disabled (real env)" — což na simulátoru s Low Power Mode off bude pravděpodobně `true`, takže tento test je effectively informational. Ošetříme v Step 3 přes protokol pro mockování.

Po praktické úvaze: pro Plan 3 stačí 2 jednoduché kontrakt testy bez mocku.

`Kojeni/KojeniTests/Services/LiveActivityManagerTests.swift`:

```swift
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
```

- [ ] **Step 2: Pusť testy — selžou**

Expected: `Cannot find 'LiveActivityManager' in scope`.

- [ ] **Step 3: Implementuj `LiveActivityManager`**

`Kojeni/Kojeni/Services/LiveActivityManager.swift`:

```swift
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
```

- [ ] **Step 4: Pusť testy — projdou**

Expected: **47 passed** (45 + 2 nové LA testy).

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/Services/LiveActivityManager.swift \
        Kojeni/KojeniTests/Services/LiveActivityManagerTests.swift
git commit -m "feat(services): LiveActivityManager (request/update/end + re-attach on init)"
```

---

## Task 6: Wire `LiveActivityManager` do UI call-sitů + inject do environment

**Files:**
- Modify: `Kojeni/Kojeni/KojeniApp.swift` (inject LA manager do environment)
- Modify: `Kojeni/Kojeni/Features/Home/BreastPickerSheet.swift` (start LA po startSession)
- Modify: `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift` (update LA po switchBreast, end LA po endSession)

**Cíl:** Live Activity orchestrace v UI vrstvě. `FeedingService` zůstává čistá data layer. Singleton-y nemáme — `LiveActivityManager` instance žije v `KojeniApp` a propaguje se přes **typovaný `@Environment(LiveActivityManager.self)`** pattern (iOS 17+, vyžaduje `@Observable` na třídě, což Task 5 už zajistil).

- [ ] **Step 1: Inject manager do `KojeniApp`**

`Kojeni/Kojeni/KojeniApp.swift`, uprav `body`:

```swift
    @State private var liveActivity = LiveActivityManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(liveActivity)
        }
        .modelContainer(container)
    }
```

> `.environment(liveActivity)` (bez key path) zaregistruje typovanou hodnotu `LiveActivityManager.self` do environment. Žádný custom `EnvironmentKey` ani `defaultValue` — `@Observable` třída se propisuje přímo.
>
> `@State` zaručí, že manager žije po celou dobu Scene; jeho `currentActivity` přežije re-render a navigace.

- [ ] **Step 2: Wire `start` v `BreastPickerSheet`**

V `Kojeni/Kojeni/Features/Home/BreastPickerSheet.swift` přidej do `@Environment` blok:

```swift
    @Environment(LiveActivityManager.self) private var liveActivity
```

A nahraď `start(with:)`:

```swift
    private func start(with breast: Breast) {
        do {
            let session = try FeedingService(context: modelContext).startSession(breast: breast)
            // Start Live Activity — sessionID jako string z PersistentIdentifier
            let sessionID = String(describing: session.persistentModelID)
            liveActivity.start(
                sessionID: sessionID,
                startedAt: session.startedAt,
                currentBreast: breast
            )
            dismiss()
        } catch {
            print("startSession failed: \(error)")
            dismiss()
        }
    }
```

> `String(describing: session.persistentModelID)` — PersistentIdentifier nemá veřejný stable string representation. Pro účely Live Activity nám stačí identifikátor pro logging; reálné dohledání sezení v App Intentu (Task 8) půjde přes `FetchDescriptor<FeedingSession>(predicate: #Predicate { $0.endedAt == nil })`, ne přes ID lookup. Tj. sessionID v Attributes je informativní.

- [ ] **Step 3: Wire `update` v `ActiveSessionView.switchBreast`**

V `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift` přidej do `@Environment` blok:

```swift
    @Environment(LiveActivityManager.self) private var liveActivity
```

Nahraď `switchBreast()`:

```swift
    private func switchBreast() {
        do {
            guard let newBreast = try FeedingService(context: modelContext).switchBreast()
            else { return }
            Task { await liveActivity.update(currentBreast: newBreast) }
        } catch {
            print("switchBreast failed: \(error)")
        }
    }
```

- [ ] **Step 4: Wire `end` v `ActiveSessionView.endSession`**

Nahraď `endSession()`:

```swift
    private func endSession() {
        do {
            guard let ended = try FeedingService(context: modelContext).endSession()
            else { return }
            endedSessionID = ended.persistentModelID
            showPumpedMlSheet = true
            Task { await liveActivity.end() }
        } catch {
            print("endSession failed: \(error)")
        }
    }
```

- [ ] **Step 5: Build + smoke na simulátoru**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination 'platform=iOS Simulator,id=E7D54495-1FBF-4E65-B7E4-F55D51806898' \
  -derivedDataPath /tmp/kojeni-build -quiet 2>&1 | tail -5
```

> Live Activity UI Plan 7 ještě nepřepsal — ale `Activity.request` vrátí success a zalogue. Ověříme console:

```bash
SIMCTL=/Applications/Xcode.app/Contents/Developer/usr/bin/simctl
SIM_ID=E7D54495-1FBF-4E65-B7E4-F55D51806898
$SIMCTL terminate $SIM_ID cz.zapletal.Kojeni 2>/dev/null
$SIMCTL install $SIM_ID /tmp/kojeni-build/Build/Products/Debug-iphonesimulator/Kojeni.app
$SIMCTL launch $SIM_ID cz.zapletal.Kojeni &
sleep 3
# Logy z procesu (filtruj na náš subsystem)
$SIMCTL spawn $SIM_ID log stream --predicate 'subsystem == "cz.zapletal.kojeni"' --style compact &
sleep 5
# (manuálně v Simulator.app tapni Kojit → Levé → ověř že v logu vidíš "Started LA for session ...")
```

> Plný smoke (vidět LA na Lock Screen) přijde až po Task 7 + Task 11 manual checklist.

- [ ] **Step 6: Pusť unit testy**

Expected: **47 passed** (žádný regress).

- [ ] **Step 7: Commit**

```bash
git add Kojeni/Kojeni/Services/LiveActivityManager.swift \
        Kojeni/Kojeni/KojeniApp.swift \
        Kojeni/Kojeni/Features/Home/BreastPickerSheet.swift \
        Kojeni/Kojeni/Features/Home/ActiveSessionView.swift
git commit -m "feat(ui): wire LiveActivityManager into start/switch/end flows"
```

---

## Task 7: `FeedingLiveActivity` widget UI (Lock Screen + Dynamic Island)

**Files:**
- Modify (or replace): `Kojeni/KojeniWidget/KojeniWidgetLiveActivity.swift` → rename na `FeedingLiveActivity.swift`
- Modify: `Kojeni/KojeniWidget/KojeniWidgetBundle.swift`
- Delete: `Kojeni/KojeniWidget/KojeniWidget.swift` (šablonový timeline widget)

**Cíl:** Skutečné Live Activity views — Lock Screen rozšířená + Dynamic Island compact + expanded. Timer přes `Text(timerInterval:)` (self-updating). Tlačítka volají `SwitchBreastIntent` a `StopFeedingIntent` (Task 8 a 9 je vytvoří — zatím použijeme placeholdery na úrovni `Button(intent: ...)` co se Task 8/9 doplní).

- [ ] **Step 1: Smaž šablonový timeline widget**

```bash
rm /Users/pz/Documents/develop/kojeni-app/Kojeni/KojeniWidget/KojeniWidget.swift
```

(Pokud Xcode 26 přidal jiné šablonové soubory pro statický widget — `IntentTimelineProvider.swift`, `StaticConfiguration` — smaž je taky. Live Activity = `ActivityConfiguration`, jiná code path.)

- [ ] **Step 2: Přejmenuj `KojeniWidgetLiveActivity.swift` → `FeedingLiveActivity.swift`**

```bash
mv /Users/pz/Documents/develop/kojeni-app/Kojeni/KojeniWidget/KojeniWidgetLiveActivity.swift \
   /Users/pz/Documents/develop/kojeni-app/Kojeni/KojeniWidget/FeedingLiveActivity.swift
```

- [ ] **Step 3: Přepiš `FeedingLiveActivity.swift`**

Obsah souboru (přepiš celý):

```swift
import ActivityKit
import SwiftUI
import WidgetKit

struct FeedingLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FeedingAttributes.self) { context in
            // Lock Screen / Notification Center
            lockScreenView(context: context)
                .padding()
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("🤱")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("Prso \(label(for: context.state.currentBreast))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timerInterval: context.attributes.sessionStartedAt...Date.distantFuture,
                             countsDown: false)
                            .font(.title3.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        Button(intent: SwitchBreastIntent()) {
                            Text("Přehodit")
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)

                        Button(intent: StopFeedingIntent()) {
                            Text("Stop")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            } compactLeading: {
                Text(label(for: context.state.currentBreast))
                    .font(.caption.bold())
            } compactTrailing: {
                Text(timerInterval: context.attributes.sessionStartedAt...Date.distantFuture,
                     countsDown: false)
                    .font(.caption.monospacedDigit())
                    .frame(maxWidth: 44)
            } minimal: {
                Text("🤱")
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<FeedingAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("🤱 Kojení")
                    .font(.headline)
                Spacer()
                Text("Prso \(label(for: context.state.currentBreast))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(timerInterval: context.attributes.sessionStartedAt...Date.distantFuture,
                 countsDown: false)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .monospacedDigit()

            HStack(spacing: 12) {
                Button(intent: SwitchBreastIntent()) {
                    Text("Přehodit prso")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(intent: StopFeedingIntent()) {
                    Text("Stop")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
        }
    }

    private func label(for breast: Breast) -> String {
        switch breast {
        case .left:  return "L"
        case .right: return "P"
        }
    }
}
```

> `SwitchBreastIntent` a `StopFeedingIntent` zatím neexistují — build selže. Vyrobíme je v Task 8 a 9.

- [ ] **Step 4: Update `KojeniWidgetBundle.swift`**

`Kojeni/KojeniWidget/KojeniWidgetBundle.swift`:

```swift
import WidgetKit
import SwiftUI

@main
struct KojeniWidgetBundle: WidgetBundle {
    var body: some Widget {
        FeedingLiveActivity()
    }
}
```

- [ ] **Step 5: Target membership pro `Breast` enum**

`FeedingLiveActivity.swift` používá `Breast` z `Kojeni/Models/Enums.swift`. Tento soubor není v target membership KojeniWidget. Otevři `Enums.swift` v Xcode → File Inspector → **Target Membership** → zaškrtni i **KojeniWidget**.

- [ ] **Step 6: Build — ZATÍM SELŽE (chybí App Intents)**

Build je očekávaný že padne s `Cannot find 'SwitchBreastIntent' in scope` a `Cannot find 'StopFeedingIntent' in scope`. To je správně. Task 8 a 9 to dořeší.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination 'platform=iOS Simulator,id=E7D54495-1FBF-4E65-B7E4-F55D51806898' \
  -quiet 2>&1 | grep "Cannot find" | head -5
```

Expected: 2 errory na missing intent typy. Build failed.

> **Nedělej commit teď.** Task 7 je incomplete dokud Task 8 a 9 nedoplní intenty. Necháme rozbité dokud Task 9 build neopraví.

---

## Task 8: `SwitchBreastIntent` (LiveActivityIntent — silent) + bulk target membership

**Files:**
- Create: `Kojeni/Kojeni/AppIntents/SwitchBreastIntent.swift`
- Xcode UI: target membership pro všechny závislosti widgetu

**Cíl:** App Intent který se spustí v Widget Extension procesu (žádné odemykání telefonu). Otevře sdílený SwiftData container (přes App Group), zavolá `FeedingService.switchBreast()`, aktualizuje Live Activity.

> **POZOR — bulk target membership.** Aby se App Intent kód zkompiloval i v KojeniWidget targetu, **všechny** typy, které importuje, musí být v KojeniWidget target membership. To jsou:
> - `Kojeni/Models/Enums.swift` (Breast — možná už hotové v Task 7 Step 5)
> - `Kojeni/Models/FeedingSession.swift`
> - `Kojeni/Models/BreastChange.swift`
> - `Kojeni/Models/DiaperEvent.swift`
> - `Kojeni/Models/AppSettings.swift`
> - `Kojeni/Models/FeedingSession+Segments.swift`
> - `Kojeni/Services/FeedingService.swift`
> - `Kojeni/Services/FeedingServiceError.swift`
> - `Kojeni/SharedAttributes/FeedingAttributes.swift` (už hotové v Task 4)
>
> V Xcode otevři každý z těchto souborů → File Inspector (pravý panel) → sekce **Target Membership** → zaškrtni **i KojeniWidget** (Kojeni nech zaškrtnuté). Pro efektivitu: select-all v navigátoru přes Shift+click, pak nastav obě targets v Inspectoru najednou.
>
> `DiaperService.swift` NEPOTŘEBUJE — App Intenty diaper neřeší.
>
> Po nastavení build by měl projít widget targetem. Selhání = chybějící membership na nějakém typu.

- [ ] **Step 1: Vytvoř `Kojeni/Kojeni/AppIntents/SwitchBreastIntent.swift`**

```bash
mkdir -p /Users/pz/Documents/develop/kojeni-app/Kojeni/Kojeni/AppIntents
```

Obsah `Kojeni/Kojeni/AppIntents/SwitchBreastIntent.swift`:

```swift
import AppIntents
import ActivityKit
import SwiftData
import Foundation
import OSLog

/// Tlačítko „Přehodit prso" v Live Activity.
/// Běží v Widget Extension procesu — neotvírá hlavní app, mamka nemusí odemykat.
struct SwitchBreastIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "Přehodit prso"

    init() {}

    func perform() async throws -> some IntentResult {
        let log = Logger(subsystem: "cz.zapletal.kojeni", category: "SwitchBreastIntent")

        // 1. Sdílený SwiftData container (App Group)
        let schema = Schema([
            FeedingSession.self,
            BreastChange.self,
            DiaperEvent.self,
            AppSettings.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.cz.zapletal.kojeni")
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // 2. Přepnutí přes FeedingService (Plan 2)
        let service = await MainActor.run { FeedingService(context: context) }
        guard let newBreast = try await MainActor.run({ try service.switchBreast() })
        else {
            log.warning("switchBreast returned nil — no active session, no-op")
            return .result()
        }

        // 3. Update Live Activity in-place
        if let activity = Activity<FeedingAttributes>.activities.first {
            await activity.update(.init(
                state: FeedingAttributes.ContentState(currentBreast: newBreast),
                staleDate: nil
            ))
            log.info("LA updated currentBreast=\(newBreast.rawValue)")
        } else {
            log.warning("No Live Activity to update")
        }

        return .result()
    }
}
```

- [ ] **Step 2: Target membership pro `SwitchBreastIntent.swift`**

V Xcode klikni na `SwitchBreastIntent.swift` → File Inspector → **Target Membership** → zaškrtni **OBA**:
- ☑ Kojeni
- ☑ KojeniWidget

Apple doporučuje sdílení App Intent typů přes oba targety. Widget UI (`Button(intent: SwitchBreastIntent())`) potřebuje typ známý v widget bundlu; system runtime na základě `LiveActivityIntent` conformance pošle execution do Widget procesu, ale typ musí být linkovatelný z obou.

- [ ] **Step 3: Build check**

Build by měl projít kromě stále chybějícího `StopFeedingIntent`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination 'platform=iOS Simulator,id=E7D54495-1FBF-4E65-B7E4-F55D51806898' \
  -quiet 2>&1 | grep "Cannot find" | head -5
```

Expected: pouze 1 error — `Cannot find 'StopFeedingIntent' in scope`.

> **Stále nedělej commit.** Task 9 doplní druhý intent a opraví build.

---

## Task 9: `StopFeedingIntent` (AppIntent — openAppWhenRun)

**Files:**
- Create: `Kojeni/Kojeni/AppIntents/StopFeedingIntent.swift`

**Cíl:** App Intent který otevře hlavní app a předá routing signál pro otevření `PumpedMlSheet`. Build musí projít. Tlačítka v Live Activity začnou fungovat (čistá akce stop nebo přehodit).

> Wiring routing signálu z intent do main app je netriviální — tento task ho zachytí v App Group UserDefaults a Task 10 ho čte v RootView.

- [ ] **Step 1: Vytvoř `Kojeni/Kojeni/AppIntents/StopFeedingIntent.swift`**

```swift
import AppIntents
import ActivityKit
import SwiftData
import Foundation
import OSLog

/// Tlačítko „Stop" v Live Activity.
/// `openAppWhenRun = true` — otevře hlavní app. App si pak otevře PumpedMlSheet.
struct StopFeedingIntent: AppIntent {

    static var title: LocalizedStringResource = "Stop"
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        let log = Logger(subsystem: "cz.zapletal.kojeni", category: "StopFeedingIntent")

        let schema = Schema([
            FeedingSession.self,
            BreastChange.self,
            DiaperEvent.self,
            AppSettings.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.cz.zapletal.kojeni")
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let service = await MainActor.run { FeedingService(context: context) }
        guard let ended = try await MainActor.run({ try service.endSession() })
        else {
            log.warning("endSession returned nil — no active session, no-op")
            return .result()
        }

        // Předáme do main app, že má otevřít PumpedMlSheet pro tuto session.
        // SwiftData PersistentIdentifier nelze přes UserDefaults serializovat přímo,
        // ale uložíme dvojici (Bool flag, sessionStart timestamp) — main app si
        // sezení dohledá podle endedAt v rozumném okně.
        let defaults = UserDefaults(suiteName: "group.cz.zapletal.kojeni")
        defaults?.set(true, forKey: "pendingPumpedMlSheet")
        defaults?.set(ended.endedAt?.timeIntervalSinceReferenceDate ?? 0,
                      forKey: "pendingPumpedMlSheet.endedAt")
        log.info("Set pendingPumpedMlSheet flag")

        // End Live Activity
        if let activity = Activity<FeedingAttributes>.activities.first {
            await activity.end(nil, dismissalPolicy: .immediate)
            log.info("LA ended")
        }

        return .result()
    }
}
```

- [ ] **Step 2: Target membership**

Stejně jako Task 8: zaškrtni **OBA** Kojeni + KojeniWidget.

- [ ] **Step 3: Build — měl by projít**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination 'platform=iOS Simulator,id=E7D54495-1FBF-4E65-B7E4-F55D51806898' \
  -quiet 2>&1 | tail -3
```

Expected: žádný error.

- [ ] **Step 4: Unit testy — pořád 47**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination 'platform=iOS Simulator,id=E7D54495-1FBF-4E65-B7E4-F55D51806898' \
  -quiet 2>&1 | grep -c "passed"
```

Expected: 47.

- [ ] **Step 5: Commit Task 7 + 8 + 9 dohromady**

```bash
git add Kojeni/KojeniWidget Kojeni/Kojeni/AppIntents Kojeni/Kojeni.xcodeproj/project.pbxproj
git commit -m "feat(widget): Live Activity UI + SwitchBreast/StopFeeding App Intents"
```

---

## Task 10: Re-attach LA + PumpedMlSheet pickup po Stop z Lock Screen

**Files:**
- Modify: `Kojeni/Kojeni/App/RootView.swift`
- Modify: `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift`

**Cíl:** Při příchodu app do `.active` scenePhase:
1. Pokud existuje běžící LA ale main app `LiveActivityManager.currentActivity == nil` (jsme po restartu) — re-attach (LA manager to dělá v `init`, ale ujistíme se že je nový instance refresh).
2. Pokud je v App Group UserDefaults `pendingPumpedMlSheet == true` — hlavní app dohledá poslední ukončené sezení a otevře `PumpedMlSheet` (refresh dat ze SwiftData přes `modelContext.processPendingChanges()`).

- [ ] **Step 1: RootView pickup PumpedMlSheet flag + ModelContext refresh**

Nahraď obsah `Kojeni/Kojeni/App/RootView.swift`:

```swift
import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsList: [AppSettings]

    @State private var showOnboarding = false
    @State private var pumpedMlPickupSessionID: PersistentIdentifier?
    @State private var showPickupSheet = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Domů", systemImage: "house.fill") }
            HistoryView()
                .tabItem { Label("Historie", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Nastavení", systemImage: "gearshape.fill") }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet()
        }
        .sheet(isPresented: $showPickupSheet) {
            if let id = pumpedMlPickupSessionID {
                PumpedMlSheet(sessionID: id)
            }
        }
        .task { handleInitialState() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                handleAppGroupPickup()
            }
        }
    }

    private func handleInitialState() {
        if settingsList.isEmpty {
            showOnboarding = true
        }
        // Při prvním spuštění také zkontroluj pickup
        handleAppGroupPickup()
    }

    private func handleAppGroupPickup() {
        let defaults = UserDefaults(suiteName: "group.cz.zapletal.kojeni")
        guard defaults?.bool(forKey: "pendingPumpedMlSheet") == true else { return }

        defaults?.set(false, forKey: "pendingPumpedMlSheet")
        let endedAtRaw = defaults?.double(forKey: "pendingPumpedMlSheet.endedAt") ?? 0
        guard endedAtRaw > 0 else { return }

        // Explicit fresh fetch — neopírám se o @Query, který může být stale
        // po cross-process zápisu z widget procesu.
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
}
```

> Cross-process SwiftData @Query auto-refresh není v iOS 26.5 garantovaný (SQLite file je sdílený přes App Group, ale notification bus mezi procesy bývá best-effort). Pickup proto používá `FetchDescriptor` přímo na `modelContext.fetch(...)` — to vyvolá čerstvý read z disku a obejde stale @Query. `allSessions` z `@Query` zůstává jen pro `settingsList` (onboarding check), kde stale je akceptovatelný.

- [ ] **Step 2: Smoke build + spustit + zkontrolovat že nic nepadlo**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination 'platform=iOS Simulator,id=E7D54495-1FBF-4E65-B7E4-F55D51806898' \
  -quiet 2>&1 | tail -3
```

- [ ] **Step 3: Unit testy**

Expected: 47.

- [ ] **Step 4: Commit**

```bash
git add Kojeni/Kojeni/App/RootView.swift
git commit -m "feat(app): pickup PumpedMlSheet after Stop from Lock Screen + scenePhase refresh"
```

---

## Task 11: Edge case — sezení > 8h (LA expired) banner

**Files:**
- Modify: `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift`

**Cíl:** Spec sekce 5 edge cases: iOS ukončí Live Activity po 8h. Pokud sezení běží > 8h (`startedAt + 8h < now`), main app ukáže žlutý banner „Pozor: sezení běží více než 8h, zkontroluj a uprav" nad timerem.

- [ ] **Step 1: Přidat banner do `ActiveSessionView`**

V `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift` přidej computed property:

```swift
    private var sessionOverEightHours: Bool {
        Date.now.timeIntervalSince(session.startedAt) > 8 * 3600
    }
```

Uprav `body` — přidej banner nad `Spacer()` (úplně nahoře pod root VStack):

```swift
    var body: some View {
        VStack(spacing: 32) {
            if sessionOverEightHours {
                VStack(spacing: 4) {
                    Text("⚠️ Sezení běží déle než 8 hodin")
                        .font(.subheadline.bold())
                    Text("Live Activity vypršela. Zkontroluj a případně uprav.")
                        .font(.caption)
                }
                .foregroundStyle(.orange)
                .padding(8)
                .background(.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }

            Spacer()
            // ... zbytek body beze změny ...
```

- [ ] **Step 2: Build + unit testy**

Expected: build succeeds, 47 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Kojeni/Kojeni/Features/Home/ActiveSessionView.swift
git commit -m "feat(ui): banner v ActiveSessionView pro sezení >8h (LA expired)"
```

---

## Task 12: E2E smoke + CHANGELOG + tag

**Files:** `CHANGELOG.md`

**Cíl:** Manuální projetí celého flow na simulátoru (Live Activity se objeví na Lock Screen, tlačítka fungují). Update CHANGELOG, tag v0.3.0.

> Live Activity v iOS Simulator funguje od iOS 16.2. Jen některé interakce (Dynamic Island) chybí — to ověříme až na fyzickém zařízení.

- [ ] **Step 1: Erase simulator + clean install**

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

- [ ] **Step 2: Manuální smoke checklist (otevři Simulator.app)**

- [ ] Onboarding ukázal, default 3 h → Hotovo.
- [ ] Tap **Kojit** → BreastPickerSheet → **Levé** → ActiveSessionView s tikajícím timerem.
- [ ] Zamkni simulator: `Device → Lock` (⌘L).
- [ ] Na Lock Screen vidím Live Activity: 🤱 Kojení, Prso L, velký timer, tlačítka [Přehodit prso] [Stop].
- [ ] Odemkni přes Touch ID (⌘D simulator).
- [ ] V live activity tap **Přehodit prso** → label „Prso P" v LA (timer neresetuje).
- [ ] Tap **Stop** → app se otevře → automaticky se ukáže PumpedMlSheet → nastav 25 ml → Uložit.
- [ ] Vidím IdleHomeView s „Poslední kojení: před … s".
- [ ] Spusť další sezení: **Kojit** → **Levé** → zamkni simulator → zkontroluj LA opět vidět → otevři Dynamic Island (long-press status bar, pokud iPhone 17 Pro to podporuje v simu) → vidím compact (L | 0:XX) a expanded (🤱 + L + timer + tlačítka).
- [ ] Force-quit app (Cmd+Shift+H × 2 v simulátoru, swipe up Kojeni). LA dál běží na Lock Screen.
- [ ] Re-launch app → ActiveSessionView se napojí na běžící sezení (re-attach), `currentBreast` reflektuje stav z LA.
- [ ] Tap **Stop** v app → PumpedMlSheet → Přeskočit → IdleHomeView.

Pokud cokoliv neprojde, zastav a oprav. **Banner test (>8h)** je nepraktický v reálném čase — můžeš ho ověřit Xcode debuggerem nebo časovým posunem simulátoru.

- [ ] **Step 3: Unit testy — finální verifikace**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -quiet 2>&1 | grep -c "passed"
```

Expected: **47**.

- [ ] **Step 4: Update `CHANGELOG.md`**

Před `## [0.2.0]` přidej:

```markdown
## [0.3.0] — Plan 3: Live Activity — 2026-06-06

- Widget Extension target `KojeniWidget` s Live Activity (Lock Screen + Dynamic Island).
- `FeedingAttributes` (ActivityKit) sdíleno mezi main app a widget targety.
- `LiveActivityManager` — request/update/end + re-attach po restartu.
- `SwitchBreastIntent` jako `LiveActivityIntent` — běží v widget procesu, žádné odemykání.
- `StopFeedingIntent` jako `AppIntent` s `openAppWhenRun = true` — otevře hlavní app pro PumpedMlSheet.
- App Group `group.cz.zapletal.kojeni` — sdílený SwiftData container mezi app a widget.
- Re-attach LA + pickup PumpedMlSheet routing přes UserDefaults na `.active` scenePhase.
- Banner v ActiveSessionView pokud sezení > 8h (LA expired).
- 5 nových Swift Testing testů (FeedingAttributes Codable × 3, LiveActivityManager × 2). Celkem 47.

```

- [ ] **Step 5: Commit + tag**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for Plan 3 live activity"
git tag -a v0.3.0 -m "Plan 3 (Live Activity) complete

- Widget Extension with Lock Screen + Dynamic Island
- FeedingAttributes shared via target membership
- LiveActivityManager (request/update/end + re-attach)
- SwitchBreastIntent (LiveActivityIntent silent)
- StopFeedingIntent (AppIntent openAppWhenRun → PumpedMlSheet pickup)
- App Group shared SwiftData container
- 47 Swift Testing tests, all green
"
```

---

## Hotovo — Plan 3 dokončen

Stav po Plan 3:
- Mamka může celé sezení odbavit s telefonem zamčeným kromě finálního ml zadání.
- Live Activity perzistuje přes restart app, force-quit, restart telefonu (iOS feature).
- Switch z Lock Screen je instantní (žádné odemykání), Stop otevře app pro ml.

**Stojí před Plan 4 (Reminders):** Implementace lokálních notifikací s akčními tlačítky („Krmím teď" / „Odložit 15 min" / „Odložit 30 min"), `ReminderScheduler` napojení na `FeedingService.endSession`.

**Známé limity Plan 3 řešitelné později:**
- Cross-process @Query auto-refresh chybí (Plan 6 — Darwin notifikace).
- Banner pro „App Group selhal" / „LA disabled" chybí (Plan 6 — polish).
- Migrace existujícího dev SwiftData store na App Group container chybí (akceptováno — dropujeme).

**Risky bits — flagged pro reálný deploy:**
- App Group entitlement re-sign přes AltStore. Pokud na maminčiném iPhone selže, fallback: `SwitchBreastIntent.openAppWhenRun = true` (Plan 3b patch).
- Cross-process SwiftData write race. Mitigace: vždy 1 zápis per akce, žádné multi-step transakce sdílené mezi procesy.
