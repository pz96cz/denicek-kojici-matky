# Kojení — Plan 1: Foundation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vytvořit kostru iOS appky — Xcode projekt, kompletní datový model (SwiftData), SwiftData container, prázdnou TabView navigaci a onboarding sheet, který se ukáže při prvním spuštění. Po doběhnutí tohoto plánu appka stojí na nohou, modely jsou plně otestované a další plány staví na hotových datech.

**Architecture:** Native iOS 17+ s SwiftUI + SwiftData. Single App target + Test target. Žádný Widget Extension v tomto plánu (přidá ho Plan 3 — Live Activity). Modely jsou izolované od UI, services se v tomto plánu ještě nepíšou. `@Environment(\.modelContext)` se předává z `RootView` dolů. Testy proti in-memory `ModelContainer`.

**Tech Stack:** Swift 5.10+, Xcode 15.4+, iOS 17.0+, SwiftUI, SwiftData, XCTest. Žádné externí dependency.

---

## File Structure (po dokončení Plan 1)

```
kojeni-app/
├── Kojeni.xcodeproj/                     ← Xcode project (vytvořen v Task 1)
├── Kojeni/                               ← App target source
│   ├── KojeniApp.swift                   ← @main, ModelContainer setup
│   ├── App/
│   │   └── RootView.swift                ← TabView shell (3 prázdné taby)
│   ├── Models/
│   │   ├── Enums.swift                   ← Breast, DiaperKind, PooConsistency
│   │   ├── FeedingSession.swift          ← @Model
│   │   ├── BreastChange.swift            ← @Model
│   │   ├── DiaperEvent.swift             ← @Model
│   │   ├── AppSettings.swift             ← @Model + first-launch helper
│   │   └── FeedingSession+Segments.swift ← derived helper segments()
│   ├── Features/
│   │   ├── Home/HomeView.swift           ← placeholder "Domů"
│   │   ├── History/HistoryView.swift     ← placeholder "Historie"
│   │   ├── Settings/SettingsView.swift   ← placeholder "Nastavení"
│   │   └── Onboarding/OnboardingSheet.swift  ← Stepper pro interval
│   ├── Resources/
│   │   ├── Assets.xcassets/              ← AccentColor + AppIcon placeholder
│   │   └── cs.lproj/Localizable.strings  ← české klíče
│   └── Info.plist                        ← portrait-only, locale cs
├── KojeniTests/
│   ├── Helpers/
│   │   └── InMemoryContainer.swift       ← test helper pro ModelContainer
│   └── Models/
│       ├── EnumsTests.swift
│       ├── FeedingSessionTests.swift
│       ├── DiaperEventTests.swift
│       └── AppSettingsTests.swift
└── docs/                                 ← už existuje (spec + plans)
```

**Soubory, které se vytvoří v pozdějších plánech a v Plan 1 neexistují:** `Services/`, `AppIntents/`, `SharedAttributes/`, `KojeniWidget/` target.

---

## Task 1: Vytvořit Xcode projekt

**Files:**
- Create: `Kojeni.xcodeproj/` (přes Xcode UI)
- Create: `.gitignore`

**Cíl:** Funkční Xcode projekt s App + Test targety, min iOS 17.0, portrait-only, otevírá se a sestaví prázdné šablonové view.

- [ ] **Step 1: Spusť Xcode 15.4+ a vytvoř nový projekt**

V Xcode: `File → New → Project…` → záložka **iOS** → šablona **App** → `Next`.

Vyplň:
- **Product Name:** `Kojeni`
- **Team:** tvůj Personal Team (free Apple ID)
- **Organization Identifier:** `cz.zapletal`
- **Bundle Identifier:** `cz.zapletal.kojeni` (vyplní se samo)
- **Interface:** `SwiftUI`
- **Language:** `Swift`
- **Storage:** `None` (SwiftData container nastavíme ručně v Task 8)
- **Include Tests:** **zaškrtnuto** ✓

Klikni `Next`. Když se zeptá kam uložit, vyber `/Users/pz/Documents/develop/kojeni-app/`. **Zruš zaškrtnutí "Create Git repository on my Mac"** — repozitář už existuje (commit f93686d).

Klikni `Create`.

- [ ] **Step 2: Nastav deployment target a portrait-only**

V Xcode levém navigátoru klikni na projekt **Kojeni** → záložka **General** → sekce **Minimum Deployments**:
- **iOS:** změň z výchozí na **17.0**

Sekce **Deployment Info**:
- **iPhone Orientation:** ponech jen `Portrait` (odznač Landscape Left/Right)
- **iPad:** odznač všechny orientace (appka cílí jen na iPhone)

Záložka **Build Settings** → vyhledej `Targeted Device Family` → nastav na `1` (iPhone).

- [ ] **Step 3: Ověř že projekt jde sestavit**

V Xcode horní liště vyber simulátor (např. **iPhone 15** s iOS 17.x) → klávesa **⌘ B**.

Expected: `Build Succeeded` v horní liště. Žádné errors.

- [ ] **Step 4: Vytvoř `.gitignore`**

V terminálu:
```bash
cd /Users/pz/Documents/develop/kojeni-app
```

Vytvoř soubor `.gitignore` s obsahem:
```
# Xcode
build/
DerivedData/
*.xcuserstate
*.xcuserdatad/
xcuserdata/

# macOS
.DS_Store

# Swift Package Manager (kdybychom někdy přidali)
.swiftpm/
Package.resolved

# Misc
*.swp
*.swo
```

- [ ] **Step 5: Commit**

```bash
cd /Users/pz/Documents/develop/kojeni-app
git add .gitignore Kojeni.xcodeproj Kojeni KojeniTests
git status   # zkontroluj, že nezahrnuje build/, DerivedData/ ani *.xcuserstate
git commit -m "chore: scaffold Xcode project (iOS 17+, portrait-only iPhone)"
```

Expected: 1 commit s šablonovými soubory `KojeniApp.swift`, `ContentView.swift`, test soubory.

---

## Task 2: Definovat enum `Breast` + test pro `opposite`

**Files:**
- Create: `Kojeni/Models/Enums.swift`
- Create: `KojeniTests/Models/EnumsTests.swift`

**Cíl:** Mít jádro typů (`Breast`, `DiaperKind`, `PooConsistency`) jako Swift enums implementující `Codable`. Test ověřuje, že `Breast.opposite` skutečně vrací opačnou stranu.

- [ ] **Step 1: Smaž šablonové `ContentView.swift`**

V Xcode pravým klikem na `ContentView.swift` → `Delete` → `Move to Trash`. Tento soubor bude nahrazen `RootView.swift` v Task 10.

Také uprav `KojeniApp.swift` (vygenerovaný šablonou) — dočasně tam zůstane `ContentView()`, opravíme v Task 8. Pokud Xcode hlásí chybu, dočasně nahraď tělo:
```swift
import SwiftUI

@main
struct KojeniApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Kojení")
        }
    }
}
```

(Nepouštěj test — chvilku to bude rozbité, opraví Task 8.)

- [ ] **Step 2: Napiš failing test pro Breast.opposite**

V Xcode pravým klikem na složku `KojeniTests` v navigátoru → `New File…` → `Swift File` → název `EnumsTests` → ulož do `KojeniTests/Models/` (vytvoř složku Models, pokud neexistuje).

Vlož obsah `KojeniTests/Models/EnumsTests.swift`:

```swift
import XCTest
@testable import Kojeni

final class EnumsTests: XCTestCase {

    func test_breast_opposite_left_returns_right() {
        XCTAssertEqual(Breast.left.opposite, .right)
    }

    func test_breast_opposite_right_returns_left() {
        XCTAssertEqual(Breast.right.opposite, .left)
    }

    func test_breast_opposite_is_involution() {
        // dvojnásobné použití vrátí původní hodnotu
        XCTAssertEqual(Breast.left.opposite.opposite, .left)
        XCTAssertEqual(Breast.right.opposite.opposite, .right)
    }
}
```

- [ ] **Step 3: Pusť test — ověř že selhává**

V Xcode horní liště vyber **simulator iPhone 15** (iOS 17.x) → klávesa **⌘ U**.

Expected: build fails — `cannot find 'Breast' in scope` v `EnumsTests.swift`. To je správně.

- [ ] **Step 4: Implementuj `Enums.swift`**

V Xcode pravým klikem na složku `Kojeni` → `New Group` → `Models`. Pak v `Models` → `New File…` → `Swift File` → `Enums.swift`.

Obsah:

```swift
import Foundation

enum Breast: String, Codable, CaseIterable {
    case left = "L"
    case right = "R"

    var opposite: Breast {
        self == .left ? .right : .left
    }
}

enum DiaperKind: String, Codable, CaseIterable {
    case pee
    case poo
}

enum PooConsistency: String, Codable, CaseIterable {
    case loose
    case normal
    case hard
}
```

- [ ] **Step 5: Pusť testy — ověř že prochází**

V Xcode **⌘ U**.

Expected: všechny 3 testy v `EnumsTests` zelené. `Test Succeeded`.

- [ ] **Step 6: Commit**

```bash
git add Kojeni/Models/Enums.swift KojeniTests/Models/EnumsTests.swift Kojeni.xcodeproj
git commit -m "feat(models): Breast, DiaperKind, PooConsistency enums + opposite test"
```

---

## Task 3: Definovat `FeedingSession` + `BreastChange` modely

**Files:**
- Create: `Kojeni/Models/FeedingSession.swift`
- Create: `Kojeni/Models/BreastChange.swift`
- Create: `KojeniTests/Models/FeedingSessionTests.swift`
- Create: `KojeniTests/Helpers/InMemoryContainer.swift`

**Cíl:** Mít hlavní entitu `FeedingSession` se vztahem na `BreastChange`. Otestovat derived properties `duration`, `isActive`, `currentBreast`. SwiftData round-trip přes in-memory container.

- [ ] **Step 1: Vytvoř test helper pro in-memory ModelContainer**

V Xcode pravým klikem na `KojeniTests` → `New Group` → `Helpers`. Pak `New File…` → `Swift File` → `InMemoryContainer.swift`.

Obsah `KojeniTests/Helpers/InMemoryContainer.swift`:

```swift
import Foundation
import SwiftData
@testable import Kojeni

enum InMemoryContainer {

    /// Vytvoří `ModelContainer` v paměti se všemi `@Model` třídami.
    /// Pro každý test instance — nepřežije mezi testy.
    @MainActor
    static func make() -> ModelContainer {
        let schema = Schema([
            FeedingSession.self,
            BreastChange.self,
            DiaperEvent.self,
            AppSettings.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
```

(Soubor zatím neselže, protože ho ještě nikdo nepoužívá — typy `DiaperEvent` a `AppSettings` zatím neexistují. **Build se zlomí**, opraví Task 5 a 6. Tohle je OK pro postupný TDD — pokud chceš čistší build, zakomentuj řádky pro `DiaperEvent.self` a `AppSettings.self` a odkomentuj v Task 5 a 6.)

Pro čistší průchod **zakomentuj** zatím `DiaperEvent.self` a `AppSettings.self`:

```swift
let schema = Schema([
    FeedingSession.self,
    BreastChange.self,
    // DiaperEvent.self,   // odkomentuj v Task 5
    // AppSettings.self,   // odkomentuj v Task 6
])
```

- [ ] **Step 2: Napiš failing test pro `FeedingSession`**

V Xcode pravým klikem na `KojeniTests/Models` → `New File…` → `Swift File` → `FeedingSessionTests.swift`.

Obsah:

```swift
import XCTest
import SwiftData
@testable import Kojeni

@MainActor
final class FeedingSessionTests: XCTestCase {

    func test_new_session_is_active() {
        let session = FeedingSession(startedAt: .now, initialBreast: .left)
        XCTAssertTrue(session.isActive)
        XCTAssertNil(session.endedAt)
    }

    func test_ended_session_is_not_active() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = start.addingTimeInterval(600)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.endedAt = end
        XCTAssertFalse(session.isActive)
    }

    func test_duration_for_ended_session() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = start.addingTimeInterval(900)   // 15 min
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.endedAt = end
        XCTAssertEqual(session.duration, 900, accuracy: 0.001)
    }

    func test_duration_for_active_session_uses_now() {
        let start = Date.now.addingTimeInterval(-60)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        // Tolerance 0.5s kvůli paralelnímu běhu testu
        XCTAssertEqual(session.duration, 60, accuracy: 0.5)
    }

    func test_currentBreast_without_changes_returns_initial() {
        let session = FeedingSession(startedAt: .now, initialBreast: .right)
        XCTAssertEqual(session.currentBreast, .right)
    }

    func test_currentBreast_returns_last_change() {
        let session = FeedingSession(startedAt: .now, initialBreast: .left)
        let t1 = Date.now.addingTimeInterval(60)
        let t2 = Date.now.addingTimeInterval(120)
        session.breastChanges = [
            BreastChange(at: t1, to: .right),
            BreastChange(at: t2, to: .left),
        ]
        XCTAssertEqual(session.currentBreast, .left)
    }

    func test_currentBreast_sorts_changes_by_time() {
        // Pořadí v poli neodpovídá chronologii — currentBreast musí seřadit podle `at`.
        let session = FeedingSession(startedAt: .now, initialBreast: .left)
        let t1 = Date.now.addingTimeInterval(60)
        let t2 = Date.now.addingTimeInterval(120)
        session.breastChanges = [
            BreastChange(at: t2, to: .left),
            BreastChange(at: t1, to: .right),
        ]
        XCTAssertEqual(session.currentBreast, .left)
    }

    func test_swiftdata_roundtrip() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.breastChanges = [BreastChange(at: start.addingTimeInterval(60), to: .right)]
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<FeedingSession>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.initialBreast, .left)
        XCTAssertEqual(fetched.first?.breastChanges.count, 1)
        XCTAssertEqual(fetched.first?.breastChanges.first?.to, .right)
    }
}
```

- [ ] **Step 3: Pusť testy — ověř že selhávají na neexistujících typech**

V Xcode **⌘ U**.

Expected: build fails — `cannot find 'FeedingSession' in scope`, `cannot find 'BreastChange' in scope`.

- [ ] **Step 4: Implementuj `BreastChange` model**

V Xcode pravým klikem na `Kojeni/Models` → `New File…` → `Swift File` → `BreastChange.swift`.

Obsah:

```swift
import Foundation
import SwiftData

@Model
final class BreastChange {
    var id: UUID
    var at: Date
    var to: Breast
    var session: FeedingSession?

    init(at: Date, to: Breast) {
        self.id = UUID()
        self.at = at
        self.to = to
    }
}
```

- [ ] **Step 5: Implementuj `FeedingSession` model**

V Xcode `Kojeni/Models` → `New File…` → `Swift File` → `FeedingSession.swift`.

Obsah:

```swift
import Foundation
import SwiftData

@Model
final class FeedingSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var initialBreast: Breast
    var pumpedMl: Int?

    @Relationship(deleteRule: .cascade, inverse: \BreastChange.session)
    var breastChanges: [BreastChange] = []

    init(startedAt: Date, initialBreast: Breast) {
        self.id = UUID()
        self.startedAt = startedAt
        self.initialBreast = initialBreast
    }

    var isActive: Bool { endedAt == nil }

    var duration: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }

    var currentBreast: Breast {
        breastChanges.sorted { $0.at < $1.at }.last?.to ?? initialBreast
    }
}
```

- [ ] **Step 6: Pusť testy — ověř že prochází**

V Xcode **⌘ U**.

Expected: všechny testy v `FeedingSessionTests` zelené (8 testů). Pokud `test_swiftdata_roundtrip` selže s "Schema neobsahuje typ", zkontroluj že `InMemoryContainer.make()` obsahuje `FeedingSession.self` a `BreastChange.self`.

- [ ] **Step 7: Commit**

```bash
git add Kojeni/Models/FeedingSession.swift Kojeni/Models/BreastChange.swift \
        KojeniTests/Models/FeedingSessionTests.swift KojeniTests/Helpers/InMemoryContainer.swift \
        Kojeni.xcodeproj
git commit -m "feat(models): FeedingSession + BreastChange with derived properties"
```

---

## Task 4: `FeedingSession+Segments` helper

**Files:**
- Create: `Kojeni/Models/FeedingSession+Segments.swift`
- Modify: `KojeniTests/Models/FeedingSessionTests.swift`

**Cíl:** Z `breastChanges` odvodit posloupnost segmentů `[(breast, start, end)]` pro UI Timeline / Detail. Computation, žádné persistence.

- [ ] **Step 1: Napiš failing test pro `segments()`**

V `KojeniTests/Models/FeedingSessionTests.swift` přidej před závěrečnou `}`:

```swift
    // MARK: - segments()

    func test_segments_for_session_without_changes_returns_single_segment() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = start.addingTimeInterval(600)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.endedAt = end

        let segments = session.segments()

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].breast, .left)
        XCTAssertEqual(segments[0].start, start)
        XCTAssertEqual(segments[0].end, end)
    }

    func test_segments_for_session_with_one_change_returns_two_segments() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let mid = start.addingTimeInterval(720)   // 12 min
        let end = start.addingTimeInterval(1080)  // 18 min
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.endedAt = end
        session.breastChanges = [BreastChange(at: mid, to: .right)]

        let segments = session.segments()

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].breast, .left)
        XCTAssertEqual(segments[0].start, start)
        XCTAssertEqual(segments[0].end, mid)
        XCTAssertEqual(segments[1].breast, .right)
        XCTAssertEqual(segments[1].start, mid)
        XCTAssertEqual(segments[1].end, end)
    }

    func test_segments_for_active_session_uses_now_as_end_of_last_segment() {
        let start = Date.now.addingTimeInterval(-300)   // před 5 min
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        // endedAt == nil → aktivní

        let segments = session.segments()

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].breast, .left)
        // tolerance 1s kvůli paralelnímu běhu
        XCTAssertEqual(segments[0].end.timeIntervalSinceReferenceDate,
                       Date.now.timeIntervalSinceReferenceDate, accuracy: 1.0)
    }

    func test_segments_sorts_changes_by_time() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let t1 = start.addingTimeInterval(60)
        let t2 = start.addingTimeInterval(120)
        let end = start.addingTimeInterval(180)
        let session = FeedingSession(startedAt: start, initialBreast: .left)
        session.endedAt = end
        // záměrně zamíchané pořadí v poli
        session.breastChanges = [
            BreastChange(at: t2, to: .left),
            BreastChange(at: t1, to: .right),
        ]

        let segments = session.segments()

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].breast, .left)
        XCTAssertEqual(segments[0].end, t1)
        XCTAssertEqual(segments[1].breast, .right)
        XCTAssertEqual(segments[1].end, t2)
        XCTAssertEqual(segments[2].breast, .left)
        XCTAssertEqual(segments[2].end, end)
    }
```

- [ ] **Step 2: Pusť testy — ověř že selhávají**

V Xcode **⌘ U**.

Expected: 4 testy fail — `value of type 'FeedingSession' has no member 'segments'`.

- [ ] **Step 3: Implementuj `segments()` v extension**

V Xcode `Kojeni/Models` → `New File…` → `Swift File` → `FeedingSession+Segments.swift`.

Obsah:

```swift
import Foundation

extension FeedingSession {

    /// Rozdělí sezení podle `breastChanges` na souvislé segmenty.
    /// Pro aktivní sezení končí poslední segment v `.now`.
    func segments() -> [(breast: Breast, start: Date, end: Date)] {
        let sortedChanges = breastChanges.sorted { $0.at < $1.at }
        let sessionEnd = endedAt ?? .now

        var result: [(breast: Breast, start: Date, end: Date)] = []
        var currentStart = startedAt
        var currentBreast = initialBreast

        for change in sortedChanges {
            result.append((breast: currentBreast, start: currentStart, end: change.at))
            currentStart = change.at
            currentBreast = change.to
        }
        result.append((breast: currentBreast, start: currentStart, end: sessionEnd))

        return result
    }
}
```

- [ ] **Step 4: Pusť testy — ověř že prochází**

V Xcode **⌘ U**. Expected: všechny testy v `FeedingSessionTests` zelené.

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Models/FeedingSession+Segments.swift KojeniTests/Models/FeedingSessionTests.swift Kojeni.xcodeproj
git commit -m "feat(models): FeedingSession.segments() derived helper"
```

---

## Task 5: `DiaperEvent` model

**Files:**
- Create: `Kojeni/Models/DiaperEvent.swift`
- Create: `KojeniTests/Models/DiaperEventTests.swift`
- Modify: `KojeniTests/Helpers/InMemoryContainer.swift`

**Cíl:** `DiaperEvent` s validací: konzistence vyplněná **právě tehdy**, když `kind == .poo`. Round-trip přes SwiftData.

- [ ] **Step 1: Napiš failing test pro `DiaperEvent`**

V Xcode pravým klikem na `KojeniTests/Models` → `New File…` → `Swift File` → `DiaperEventTests.swift`.

Obsah:

```swift
import XCTest
import SwiftData
@testable import Kojeni

@MainActor
final class DiaperEventTests: XCTestCase {

    func test_pee_event_has_no_consistency() {
        let event = DiaperEvent(at: .now, kind: .pee)
        XCTAssertEqual(event.kind, .pee)
        XCTAssertNil(event.consistency)
    }

    func test_poo_event_with_consistency() {
        let event = DiaperEvent(at: .now, kind: .poo, consistency: .normal)
        XCTAssertEqual(event.kind, .poo)
        XCTAssertEqual(event.consistency, .normal)
    }

    func test_pee_event_ignores_consistency_argument() {
        // Pee nikdy nesmí mít konzistenci, i kdyby ji někdo poslal.
        let event = DiaperEvent(at: .now, kind: .pee, consistency: .normal)
        XCTAssertNil(event.consistency, "Pee event must drop consistency argument")
    }

    func test_swiftdata_roundtrip() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        let event = DiaperEvent(at: .now, kind: .poo, consistency: .loose)
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DiaperEvent>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.kind, .poo)
        XCTAssertEqual(fetched.first?.consistency, .loose)
    }
}
```

- [ ] **Step 2: Pusť testy — ověř že selhávají**

V Xcode **⌘ U**.

Expected: build fails — `cannot find 'DiaperEvent' in scope`.

- [ ] **Step 3: Implementuj `DiaperEvent` model**

V Xcode `Kojeni/Models` → `New File…` → `Swift File` → `DiaperEvent.swift`.

Obsah:

```swift
import Foundation
import SwiftData

@Model
final class DiaperEvent {
    var id: UUID
    var at: Date
    var kind: DiaperKind
    var consistency: PooConsistency?

    init(at: Date, kind: DiaperKind, consistency: PooConsistency? = nil) {
        self.id = UUID()
        self.at = at
        self.kind = kind
        // Invariant: konzistence existuje právě pro kakání
        self.consistency = (kind == .poo) ? consistency : nil
    }
}
```

- [ ] **Step 4: Odkomentuj `DiaperEvent.self` ve `InMemoryContainer.swift`**

V `KojeniTests/Helpers/InMemoryContainer.swift` změň:

```swift
let schema = Schema([
    FeedingSession.self,
    BreastChange.self,
    DiaperEvent.self,           // ← odkomentováno
    // AppSettings.self,        // odkomentuj v Task 6
])
```

- [ ] **Step 5: Pusť testy — ověř že prochází**

V Xcode **⌘ U**. Expected: všechny testy v `DiaperEventTests` zelené.

- [ ] **Step 6: Commit**

```bash
git add Kojeni/Models/DiaperEvent.swift KojeniTests/Models/DiaperEventTests.swift \
        KojeniTests/Helpers/InMemoryContainer.swift Kojeni.xcodeproj
git commit -m "feat(models): DiaperEvent with consistency invariant"
```

---

## Task 6: `AppSettings` model + first-launch helper

**Files:**
- Create: `Kojeni/Models/AppSettings.swift`
- Create: `KojeniTests/Models/AppSettingsTests.swift`
- Modify: `KojeniTests/Helpers/InMemoryContainer.swift`

**Cíl:** Single-row `AppSettings` s defaulty (interval 180, enabled true). Helper `loadOrCreate(in:)` který buď načte existující, nebo založí nový s defaulty. Rozsah intervalu **30…360** validuje computed setter.

- [ ] **Step 1: Napiš failing test pro `AppSettings`**

V Xcode pravým klikem na `KojeniTests/Models` → `New File…` → `Swift File` → `AppSettingsTests.swift`.

Obsah:

```swift
import XCTest
import SwiftData
@testable import Kojeni

@MainActor
final class AppSettingsTests: XCTestCase {

    func test_default_values() {
        let settings = AppSettings()
        XCTAssertEqual(settings.reminderIntervalMinutes, 180)
        XCTAssertTrue(settings.remindersEnabled)
    }

    func test_custom_values_in_range() {
        let settings = AppSettings(reminderIntervalMinutes: 120, remindersEnabled: false)
        XCTAssertEqual(settings.reminderIntervalMinutes, 120)
        XCTAssertFalse(settings.remindersEnabled)
    }

    func test_interval_below_minimum_is_clamped() {
        let settings = AppSettings(reminderIntervalMinutes: 10)
        XCTAssertEqual(settings.reminderIntervalMinutes, 30, "Below-min should clamp to 30")
    }

    func test_interval_above_maximum_is_clamped() {
        let settings = AppSettings(reminderIntervalMinutes: 9999)
        XCTAssertEqual(settings.reminderIntervalMinutes, 360, "Above-max should clamp to 360")
    }

    func test_loadOrCreate_returns_existing() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        let existing = AppSettings(reminderIntervalMinutes: 240)
        context.insert(existing)
        try context.save()

        let loaded = try AppSettings.loadOrCreate(in: context)

        XCTAssertEqual(loaded.reminderIntervalMinutes, 240)
        // Žádný nový řádek nepřibyl
        let count = try context.fetch(FetchDescriptor<AppSettings>()).count
        XCTAssertEqual(count, 1)
    }

    func test_loadOrCreate_creates_with_defaults_when_missing() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)

        let loaded = try AppSettings.loadOrCreate(in: context)

        XCTAssertEqual(loaded.reminderIntervalMinutes, 180)
        XCTAssertTrue(loaded.remindersEnabled)
        let count = try context.fetch(FetchDescriptor<AppSettings>()).count
        XCTAssertEqual(count, 1)
    }
}
```

- [ ] **Step 2: Pusť testy — ověř že selhávají**

V Xcode **⌘ U**. Expected: build fails — `cannot find 'AppSettings' in scope`.

- [ ] **Step 3: Implementuj `AppSettings` model**

V Xcode `Kojeni/Models` → `New File…` → `Swift File` → `AppSettings.swift`.

Obsah:

```swift
import Foundation
import SwiftData

@Model
final class AppSettings {

    static let minIntervalMinutes = 30
    static let maxIntervalMinutes = 360
    static let defaultIntervalMinutes = 180

    private var storedIntervalMinutes: Int
    var remindersEnabled: Bool

    /// Clamping setter — zaručí rozsah 30…360.
    var reminderIntervalMinutes: Int {
        get { storedIntervalMinutes }
        set {
            storedIntervalMinutes = min(
                max(newValue, Self.minIntervalMinutes),
                Self.maxIntervalMinutes
            )
        }
    }

    init(reminderIntervalMinutes: Int = AppSettings.defaultIntervalMinutes,
         remindersEnabled: Bool = true) {
        self.storedIntervalMinutes = min(
            max(reminderIntervalMinutes, Self.minIntervalMinutes),
            Self.maxIntervalMinutes
        )
        self.remindersEnabled = remindersEnabled
    }

    /// Načte existující řádek, nebo vytvoří a uloží nový s defaulty.
    /// V DB je vždy maximálně 1 řádek `AppSettings`.
    @MainActor
    static func loadOrCreate(in context: ModelContext) throws -> AppSettings {
        let existing = try context.fetch(FetchDescriptor<AppSettings>())
        if let first = existing.first {
            return first
        }
        let new = AppSettings()
        context.insert(new)
        try context.save()
        return new
    }
}
```

- [ ] **Step 4: Odkomentuj `AppSettings.self` ve `InMemoryContainer.swift`**

V `KojeniTests/Helpers/InMemoryContainer.swift` změň:

```swift
let schema = Schema([
    FeedingSession.self,
    BreastChange.self,
    DiaperEvent.self,
    AppSettings.self,           // ← odkomentováno
])
```

- [ ] **Step 5: Pusť testy — ověř že prochází**

V Xcode **⌘ U**. Expected: všechny testy v `AppSettingsTests` zelené (6 testů).

- [ ] **Step 6: Commit**

```bash
git add Kojeni/Models/AppSettings.swift KojeniTests/Models/AppSettingsTests.swift \
        KojeniTests/Helpers/InMemoryContainer.swift Kojeni.xcodeproj
git commit -m "feat(models): AppSettings with clamping + loadOrCreate"
```

---

## Task 7: Nastavit `ModelContainer` v `KojeniApp`

**Files:**
- Modify: `Kojeni/KojeniApp.swift`

**Cíl:** Production `ModelContainer` (SQLite na disku) se všemi 4 modely. Inject přes `.modelContainer(...)` modifier do `RootView` (kterou napíše Task 8).

- [ ] **Step 1: Nahraď obsah `Kojeni/KojeniApp.swift`**

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
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer selhalo při startu: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // RootView vznikne v Task 8. Zatím placeholder:
            Text("Kojení – container OK")
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 2: Sestav projekt — ověř že běží**

V Xcode **⌘ B**.

Expected: `Build Succeeded`. Spusť na simulátoru **⌘ R**. Měl by se ukázat text „Kojení – container OK". Žádný crash při startu (SwiftData container se inicializuje OK).

- [ ] **Step 3: Pusť testy — nesmí se nic rozbít**

V Xcode **⌘ U**. Expected: všechny existující testy zůstávají zelené.

- [ ] **Step 4: Commit**

```bash
git add Kojeni/KojeniApp.swift Kojeni.xcodeproj
git commit -m "feat(app): production ModelContainer with all entities"
```

---

## Task 8: `RootView` s TabView (3 prázdné taby)

**Files:**
- Create: `Kojeni/App/RootView.swift`
- Create: `Kojeni/Features/Home/HomeView.swift`
- Create: `Kojeni/Features/History/HistoryView.swift`
- Create: `Kojeni/Features/Settings/SettingsView.swift`
- Modify: `Kojeni/KojeniApp.swift`

**Cíl:** Funkční tab navigace mezi 3 prázdnými obrazovkami. Tab labely česky, ikony SF Symbols.

- [ ] **Step 1: Vytvoř placeholder views**

V Xcode `Kojeni` → `New Group` → `App`. V `App` → `New File…` → `Swift File` → `RootView.swift`. Obsah:

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Domů", systemImage: "house.fill")
                }

            HistoryView()
                .tabItem {
                    Label("Historie", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Nastavení", systemImage: "gearshape.fill")
                }
        }
    }
}
```

V `Kojeni` → `New Group` → `Features`. V `Features` → `New Group` → `Home`. V `Home` → `New File…` → `HomeView.swift`:

```swift
import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            Text("Domů")
                .navigationTitle("Domů")
        }
    }
}

#Preview {
    HomeView()
}
```

V `Features` → `New Group` → `History` → `New File…` → `HistoryView.swift`:

```swift
import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            Text("Historie")
                .navigationTitle("Historie")
        }
    }
}

#Preview {
    HistoryView()
}
```

V `Features` → `New Group` → `Settings` → `New File…` → `SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text("Nastavení")
                .navigationTitle("Nastavení")
        }
    }
}

#Preview {
    SettingsView()
}
```

- [ ] **Step 2: Nahraď placeholder v `KojeniApp.swift` za `RootView()`**

V `Kojeni/KojeniApp.swift`, řádek `Text("Kojení – container OK")` nahraď za:

```swift
RootView()
```

Výsledný `body`:

```swift
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
```

- [ ] **Step 3: Spusť app na simulátoru — ověř taby**

V Xcode **⌘ R**.

Expected: TabBar dole se 3 záložkami: Domů (dům), Historie (graf), Nastavení (ozubené kolo). Přepínání mezi taby funguje, každý ukáže český název ve velkém title.

- [ ] **Step 4: Pusť testy — nic se nesmí rozbít**

V Xcode **⌘ U**. Expected: všechny existující testy zelené.

- [ ] **Step 5: Commit**

```bash
git add Kojeni/App Kojeni/Features Kojeni/KojeniApp.swift Kojeni.xcodeproj
git commit -m "feat(ui): RootView with 3-tab navigation (Home/History/Settings)"
```

---

## Task 9: `OnboardingSheet` + first-launch logika

**Files:**
- Create: `Kojeni/Features/Onboarding/OnboardingSheet.swift`
- Modify: `Kojeni/App/RootView.swift`

**Cíl:** Při prvním spuštění (žádný `AppSettings` v DB) se ukáže fullscreen sheet s jediným Stepperem (interval 30…360 min, default 180, krok 15). Tap „Hotovo" uloží AppSettings a zavře sheet. Při dalších spuštěních se sheet už neukáže.

- [ ] **Step 1: Vytvoř `OnboardingSheet.swift`**

V Xcode `Kojeni/Features` → `New Group` → `Onboarding`. V `Onboarding` → `New File…` → `Swift File` → `OnboardingSheet.swift`.

Obsah:

```swift
import SwiftUI
import SwiftData

struct OnboardingSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var intervalMinutes: Int = AppSettings.defaultIntervalMinutes

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("Vítej v Kojení 🤱")
                    .font(.largeTitle.bold())
                Text("Po každém kojení ti připomeneme další krmení.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Text("Jak často chceš připomenout?")
                    .font(.headline)
                Stepper(value: $intervalMinutes,
                        in: AppSettings.minIntervalMinutes...AppSettings.maxIntervalMinutes,
                        step: 15) {
                    Text(formattedInterval)
                        .font(.title2.monospacedDigit())
                }
                .padding(.horizontal)
            }

            Spacer()

            Button(action: saveAndClose) {
                Text("Hotovo")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
        .interactiveDismissDisabled()   // sheet nelze swipnout pryč
    }

    private var formattedInterval: String {
        let hours = intervalMinutes / 60
        let minutes = intervalMinutes % 60
        if minutes == 0 {
            return "\(hours) h"
        } else if hours == 0 {
            return "\(minutes) min"
        } else {
            return "\(hours) h \(minutes) min"
        }
    }

    private func saveAndClose() {
        do {
            let settings = try AppSettings.loadOrCreate(in: modelContext)
            settings.reminderIntervalMinutes = intervalMinutes
            try modelContext.save()
            dismiss()
        } catch {
            // Logování zatím triviálně přes print; bohatší error handling až Plan 6.
            print("OnboardingSheet save failed: \(error)")
            dismiss()
        }
    }
}

#Preview {
    OnboardingSheet()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
```

- [ ] **Step 2: Uprav `RootView` aby ukázal onboarding na první spuštění**

Nahraď obsah `Kojeni/App/RootView.swift`:

```swift
import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Domů", systemImage: "house.fill")
                }

            HistoryView()
                .tabItem {
                    Label("Historie", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Nastavení", systemImage: "gearshape.fill")
                }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet()
        }
        .task {
            // První spuštění: žádný řádek AppSettings → ukaž onboarding
            if settingsList.isEmpty {
                showOnboarding = true
            }
        }
    }
}
```

- [ ] **Step 3: Spusť na simulátoru — ověř first-launch flow**

Na simulátoru: `Device → Erase All Content and Settings…`. (SwiftData store žije ve filesystému simulátoru, ne v Xcode build folderu — proto Erase, ne Clean.)

Pak **⌘ R**.

Expected:
- Po startu se okamžitě ukáže OnboardingSheet (fullscreen, nelze swipnout).
- Stepper ukazuje „3 h" (default 180 min).
- Lze měnit po 15 min, rozsah 30 min až 6 h.
- Tap „Hotovo" → sheet zmizí, vidíš TabView.
- Quit app (⌘ shift H × 2 + swipe up). Znovu **⌘ R** → onboarding se **NEukáže** (AppSettings už existuje).

- [ ] **Step 4: Pusť testy — nic se nesmí rozbít**

V Xcode **⌘ U**. Expected: všechny existující testy zelené.

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Features/Onboarding Kojeni/App/RootView.swift Kojeni.xcodeproj
git commit -m "feat(onboarding): show OnboardingSheet on first launch, save interval to AppSettings"
```

---

## Task 10: Localizable.strings (cs) base

**Files:**
- Create: `Kojeni/Resources/cs.lproj/Localizable.strings`
- Modify: Xcode project settings (development localization → `cs`)

**Cíl:** Naťahané texty z TabView, RootView, OnboardingSheet, HomeView, HistoryView, SettingsView jsou přes `String(localized:)` / `LocalizedStringKey`. Soubor `Localizable.strings` v češtině existuje a appka ho používá.

> Pro Plan 1 nemůžeme refaktorovat všechen text — vytvoříme prázdný soubor s klíči pro budoucí použití. Skutečnou lokalizaci jednotlivých view řešíme v Plan 2+.

- [ ] **Step 1: Přidat `cs` jako development localization v Xcode**

V Xcode → projekt **Kojeni** → záložka **Info** → sekce **Localizations**:
- Pod tlačítkem `+` přidej `Czech (cs)`.

Také v záložce **Build Settings** → vyhledej `Development Language` → změň na `Czech`.

(Apple development language ovlivňuje, který string je „source" a který je překlad. Pro češtinu jako zdrojový jazyk by celý SwiftUI text měl už dnes říkat „Domů" / „Historie" — což funguje, protože jsme to napsali přímo do kódu.)

- [ ] **Step 2: Vytvoř `Localizable.strings` (cs)**

V Xcode `Kojeni` → `New Group` → `Resources`. V `Resources` → pravým klikem → `New File…` → `Strings File` → název `Localizable`.

Po vytvoření klikni na soubor → v inspektoru vpravo (pravý panel) `File Inspector` → sekce `Localization` → tlačítko `Localize…` → vyber `Czech`.

Obsah `Kojeni/Resources/cs.lproj/Localizable.strings`:

```
/* TabView labels */
"tab.home" = "Domů";
"tab.history" = "Historie";
"tab.settings" = "Nastavení";

/* Home */
"home.title" = "Domů";
"home.button.start" = "Kojit";
"home.button.stop" = "Stop";
"home.button.switch" = "Přehodit prso";
"home.diaper.pee" = "Čůrání";
"home.diaper.poo" = "Kakání";
"home.last_feeding.prefix" = "Poslední kojení: před ";
"home.no_feeding_yet" = "Zatím žádné kojení";

/* History */
"history.title" = "Historie";
"history.segment.today" = "Dnes";
"history.segment.week" = "Týden";
"history.segment.list" = "Seznam";
"history.segment.stats" = "Statistiky";

/* Settings */
"settings.title" = "Nastavení";
"settings.interval" = "Interval mezi kojeními";
"settings.reminders_enabled" = "Připomínky zapnuté";
"settings.about.version" = "Verze";

/* Onboarding */
"onboarding.welcome" = "Vítej v Kojení 🤱";
"onboarding.subtitle" = "Po každém kojení ti připomeneme další krmení.";
"onboarding.interval_prompt" = "Jak často chceš připomenout?";
"onboarding.done" = "Hotovo";

/* Breast */
"breast.left" = "Levé";
"breast.right" = "Pravé";

/* Diaper consistency */
"consistency.loose" = "Řídké";
"consistency.normal" = "Normální";
"consistency.hard" = "Tvrdé";

/* Errors / banners */
"error.save_failed" = "Nepodařilo se uložit, zkus znovu.";
"banner.notifications_disabled" = "Reminder nefunguje — zapni notifikace v Nastaveních.";
```

- [ ] **Step 3: Sestav & ověř že nic nespadlo**

V Xcode **⌘ B**. Expected: `Build Succeeded`.

> Texty se zatím **nepoužívají** jako klíče — view jsou napsané s literály („Domů"). Plan 2+ provede refaktor na `Text("home.title")` jednotlivých view. Pro tento plán nám stačí, že soubor `Localizable.strings` v `cs.lproj/` existuje a je registrovaný v Xcode.

- [ ] **Step 4: Commit**

```bash
git add Kojeni/Resources Kojeni.xcodeproj
git commit -m "chore(i18n): add Czech Localizable.strings base"
```

---

## Task 11: Manuální smoke test celé foundation

**Files:** žádné nové, jen verifikace.

**Cíl:** Ověřit, že po Plan 1 appka stojí na nohou. Tohle není test code — jen checklist co odškrtnout v simulátoru.

- [ ] **Step 1: Erase simulator + clean build**

V simulátoru: `Device → Erase All Content and Settings…`. V Xcode: `Product → Clean Build Folder` (⇧⌘K).

- [ ] **Step 2: Smoke checklist**

V Xcode **⌘ R** a projdi:

- [ ] App se spustí bez crashe.
- [ ] OnboardingSheet se objeví automaticky.
- [ ] Stepper jde nahoru/dolů po 15 min, rozsah 30 min – 6 h.
- [ ] Tap „Hotovo" zavře sheet.
- [ ] Vidím TabBar se 3 taby (Domů, Historie, Nastavení) — všechny labely česky.
- [ ] Přepínání mezi taby funguje, každý tab ukáže český title.
- [ ] Quit app, znovu spustit → onboarding se neukáže (AppSettings už existuje).
- [ ] V Xcode `⌘ U` → všechny unit testy zelené (Enums, FeedingSession × 8+, segments × 4, DiaperEvent × 4, AppSettings × 6).

- [ ] **Step 3: Commit checklist do CHANGELOG**

Vytvoř soubor `CHANGELOG.md` v rootu (`/Users/pz/Documents/develop/kojeni-app/CHANGELOG.md`):

```markdown
# Changelog

## [0.1.0] — Plan 1: Foundation — 2026-06-06

- Xcode projekt (iOS 17+, portrait-only iPhone).
- SwiftData modely: FeedingSession, BreastChange, DiaperEvent, AppSettings.
- Production ModelContainer v @main App.
- TabView shell: Domů / Historie / Nastavení (placeholdery).
- OnboardingSheet při prvním spuštění s nastavením intervalu reminderu (30–360 min, default 180).
- Localizable.strings (cs) base.
- Unit testy modelů + segments helper + AppSettings clamping.
```

Commit:

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for Plan 1 foundation"
```

---

## Hotovo — Plan 1 dokončen

Stav po Plan 1:
- Appka jde nainstalovat na simulátor i fyzický telefon (Xcode → Run on My iPhone).
- Datový model je kompletní a otestovaný (~20 unit testů, coverage modelů blízko 100 %).
- Onboarding flow funguje.
- Plán 2 (Feeding core) staví na: `FeedingSession`, `BreastChange`, `AppSettings`, `RootView`, `HomeView` (placeholder), `OnboardingSheet`, `InMemoryContainer.make()`.

**Plán 2 se napíše až po manuálním ověření Plan 1.**
