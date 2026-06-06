# Kojení — Plan 2: Feeding core

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reálný in-app kojicí flow — služby `FeedingService` (start/switch/end s invarianty) a `DiaperService` (pee/poo log), HomeView se dvěma stavy (Idle / Active), výběr prsa, běžící timer, Stop s návazným ml dialogem, pleny v rychlém záznamu. Po doběhnutí tohoto plánu mamka může reálně používat appku v telefonu (bez Live Activity a notifikací — ty přidá Plan 3 a 4).

**Architecture:** SwiftUI views odebírají `ModelContext` z `@Environment` a konstruují stateless `@MainActor` služby in-place. Views reagují na DB stav přes `@Query`. Žádné singletony, žádný observable view-modely zatím — služby + `@Query` jsou dost. SwiftData transakce per akce. Žádné async — modelContext je hlavní vlákno.

**Tech Stack:** Swift 6+, Xcode 26+, iOS 26.5+, SwiftUI, SwiftData, Swift Testing. Žádné externí dependency.

> Plan navazuje na Plan 1 (Foundation). Předpokládá `Kojeni/Kojeni/Models/*.swift` (4 entity), `KojeniTests/Helpers/InMemoryContainer.swift`, `RootView`, `HomeView` (placeholder).

---

## File Structure (po dokončení Plan 2)

```
Kojeni/Kojeni/
├── KojeniApp.swift                          ← (beze změny)
├── App/
│   └── RootView.swift                       ← (beze změny)
├── Models/                                  ← (beze změny — vše z Plan 1)
├── Services/                                ← NOVÉ
│   ├── FeedingService.swift                 ← startSession/switchBreast/endSession + activeSession
│   ├── FeedingServiceError.swift            ← enum chyb
│   └── DiaperService.swift                  ← logPee/logPoo
└── Features/
    ├── Home/
    │   ├── HomeView.swift                   ← PŘEPSAT — branch idle vs active
    │   ├── IdleHomeView.swift               ← NOVÉ
    │   ├── ActiveSessionView.swift          ← NOVÉ
    │   └── BreastPickerSheet.swift          ← NOVÉ
    └── PostFeed/                            ← NOVÁ složka
        ├── PumpedMlSheet.swift              ← NOVÉ
        └── DiaperSheet.swift                ← NOVÉ

Kojeni/KojeniTests/
└── Services/                                ← NOVÁ složka
    ├── FeedingServiceTests.swift            ← NOVÉ
    └── DiaperServiceTests.swift             ← NOVÉ
```

**Vědomě NEpatří do Plan 2** (přijdou později):
- Live Activity / Widget Extension (Plan 3)
- Lokální notifikace, snooze (Plan 4)
- History views (Plan 5)
- Re-otvíraní PumpedMlSheet při restartu pokud `pumpedMl == nil` (Plan 6 — spec sekce 2)
- Error banner při SwiftData failure (Plan 6)
- Lokalizace přes `Localizable.strings` (Plan 6)

---

## Task 1: `FeedingService` skeleton + test scaffolding

**Files:**
- Create: `Kojeni/Kojeni/Services/FeedingService.swift`
- Create: `Kojeni/Kojeni/Services/FeedingServiceError.swift`
- Create: `Kojeni/KojeniTests/Services/FeedingServiceTests.swift`

**Cíl:** `FeedingService` třída s injekcí `ModelContext`, prázdná metoda `activeSession()`. Suite s test container helperem. Jeden test: `activeSession()` na prázdné DB vrátí `nil`.

- [ ] **Step 1: Napiš failing test pro `activeSession()` na prázdné DB**

V Xcode nebo přes Write — vytvoř `Kojeni/KojeniTests/Services/FeedingServiceTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import Kojeni

@Suite @MainActor
struct FeedingServiceTests {

    private func makeService() -> (FeedingService, ModelContext) {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        return (FeedingService(context: context), context)
    }

    @Test func activeSession_returns_nil_when_db_empty() throws {
        let (service, _) = makeService()
        #expect(try service.activeSession() == nil)
    }
}
```

- [ ] **Step 2: Pusť testy — ověř že selhávají**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination 'platform=iOS Simulator,id=E7D54495-1FBF-4E65-B7E4-F55D51806898' \
  -quiet 2>&1 | grep -E "(passed|failed|error:|Cannot find)" | tail -10
```

(SIM ID si vyhledej `simctl list devices available | grep "iPhone.*(Booted)"`)

Expected: build fails — `Cannot find 'FeedingService' in scope`.

- [ ] **Step 3: Implementuj `FeedingServiceError`**

`Kojeni/Kojeni/Services/FeedingServiceError.swift`:

```swift
import Foundation

enum FeedingServiceError: Error, Equatable {
    case sessionAlreadyActive
}
```

- [ ] **Step 4: Implementuj `FeedingService` skeleton**

`Kojeni/Kojeni/Services/FeedingService.swift`:

```swift
import Foundation
import SwiftData

@MainActor
final class FeedingService {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Vrátí aktivní (běžící) sezení, nebo `nil` pokud žádné neběží.
    /// V DB je z invariantu maximálně 1 aktivní sezení.
    func activeSession() throws -> FeedingSession? {
        let descriptor = FetchDescriptor<FeedingSession>(
            predicate: #Predicate { $0.endedAt == nil }
        )
        return try context.fetch(descriptor).first
    }
}
```

- [ ] **Step 5: Pusť testy — ověř že prochází**

Stejný xcodebuild příkaz jako Step 2.

Expected: 26 passed (25 z Plan 1 + nový `activeSession_returns_nil_when_db_empty`).

- [ ] **Step 6: Commit**

```bash
git add Kojeni/Kojeni/Services/FeedingService.swift \
        Kojeni/Kojeni/Services/FeedingServiceError.swift \
        Kojeni/KojeniTests/Services/FeedingServiceTests.swift
git commit -m "feat(services): FeedingService skeleton with activeSession()"
```

---

## Task 2: `FeedingService.startSession` + invariant test

**Files:**
- Modify: `Kojeni/Kojeni/Services/FeedingService.swift`
- Modify: `Kojeni/KojeniTests/Services/FeedingServiceTests.swift`

**Cíl:** Start sezení vloží `FeedingSession` s daným prsem a `endedAt == nil`. Pokud aktivní sezení existuje, hodí `sessionAlreadyActive`.

- [ ] **Step 1: Napiš failing testy pro `startSession`**

Do `FeedingServiceTests` přidej před závěrečnou `}`:

```swift
    // MARK: - startSession

    @Test func startSession_inserts_active_session() throws {
        let (service, context) = makeService()
        let session = try service.startSession(breast: .left)

        #expect(session.initialBreast == .left)
        #expect(session.isActive)
        #expect(session.endedAt == nil)

        let all = try context.fetch(FetchDescriptor<FeedingSession>())
        #expect(all.count == 1)
        #expect(all.first?.initialBreast == .left)
    }

    @Test func startSession_with_explicit_date() throws {
        let (service, _) = makeService()
        let when = Date(timeIntervalSinceReferenceDate: 12345)
        let session = try service.startSession(breast: .right, at: when)
        #expect(session.startedAt == when)
        #expect(session.initialBreast == .right)
    }

    @Test func startSession_throws_when_active_session_exists() throws {
        let (service, _) = makeService()
        _ = try service.startSession(breast: .left)

        #expect(throws: FeedingServiceError.sessionAlreadyActive) {
            try service.startSession(breast: .right)
        }
    }

    @Test func startSession_after_previous_ended_is_allowed() throws {
        let (service, context) = makeService()
        let first = try service.startSession(breast: .left)
        first.endedAt = .now
        try context.save()

        let second = try service.startSession(breast: .right)
        #expect(second.initialBreast == .right)
        #expect(second.isActive)
    }
```

- [ ] **Step 2: Pusť testy — ověř že selhávají**

Expected: 4 nové testy selžou — `value of type 'FeedingService' has no member 'startSession'`.

- [ ] **Step 3: Implementuj `startSession`**

Do `FeedingService` přidej (před závěrečnou `}`):

```swift
    /// Spustí nové sezení s daným prsem.
    /// Throws `sessionAlreadyActive` pokud už nějaké aktivní existuje.
    @discardableResult
    func startSession(breast: Breast, at date: Date = .now) throws -> FeedingSession {
        if try activeSession() != nil {
            throw FeedingServiceError.sessionAlreadyActive
        }
        let session = FeedingSession(startedAt: date, initialBreast: breast)
        context.insert(session)
        try context.save()
        return session
    }
```

- [ ] **Step 4: Pusť testy — ověř že prochází**

Expected: 30 passed (26 + 4 nové).

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/Services/FeedingService.swift \
        Kojeni/KojeniTests/Services/FeedingServiceTests.swift
git commit -m "feat(services): FeedingService.startSession with active-session invariant"
```

---

## Task 3: `FeedingService.switchBreast`

**Files:**
- Modify: `Kojeni/Kojeni/Services/FeedingService.swift`
- Modify: `Kojeni/KojeniTests/Services/FeedingServiceTests.swift`

**Cíl:** Přepnutí prsa apenduje `BreastChange` na aktivní sezení. Mění na opačné prso. No-op (vrátí `nil`) když žádné aktivní sezení neběží. Timer (`startedAt`) se nemění.

- [ ] **Step 1: Napiš failing testy pro `switchBreast`**

Do `FeedingServiceTests`:

```swift
    // MARK: - switchBreast

    @Test func switchBreast_appends_change_and_switches_to_opposite() throws {
        let (service, _) = makeService()
        _ = try service.startSession(breast: .left)

        let newBreast = try service.switchBreast()

        #expect(newBreast == .right)
        let session = try service.activeSession()
        #expect(session?.breastChanges.count == 1)
        #expect(session?.currentBreast == .right)
        #expect(session?.breastChanges.first?.to == .right)
    }

    @Test func switchBreast_does_not_change_startedAt() throws {
        let (service, _) = makeService()
        let session = try service.startSession(breast: .left)
        let originalStart = session.startedAt

        _ = try service.switchBreast()

        let after = try service.activeSession()
        #expect(after?.startedAt == originalStart)
    }

    @Test func switchBreast_multiple_times_alternates() throws {
        let (service, _) = makeService()
        _ = try service.startSession(breast: .left)

        _ = try service.switchBreast()  // → R
        _ = try service.switchBreast()  // → L
        _ = try service.switchBreast()  // → R

        let session = try service.activeSession()
        #expect(session?.breastChanges.count == 3)
        #expect(session?.currentBreast == .right)
    }

    @Test func switchBreast_returns_nil_when_no_active_session() throws {
        let (service, _) = makeService()
        let result = try service.switchBreast()
        #expect(result == nil)
    }

    @Test func switchBreast_uses_provided_date() throws {
        let (service, _) = makeService()
        _ = try service.startSession(breast: .left)
        let when = Date(timeIntervalSinceReferenceDate: 99999)

        _ = try service.switchBreast(at: when)

        let session = try service.activeSession()
        #expect(session?.breastChanges.first?.at == when)
    }
```

- [ ] **Step 2: Pusť testy — ověř že selhávají**

Expected: 5 nových testů selže — `value of type 'FeedingService' has no member 'switchBreast'`.

- [ ] **Step 3: Implementuj `switchBreast`**

Do `FeedingService`:

```swift
    /// Přepne na opačné prso v aktivním sezení. No-op když žádné neběží.
    /// Vrací nové aktuální prso, nebo `nil` při no-op.
    @discardableResult
    func switchBreast(at date: Date = .now) throws -> Breast? {
        guard let session = try activeSession() else { return nil }
        let next = session.currentBreast.opposite
        let change = BreastChange(at: date, to: next)
        change.session = session
        session.breastChanges.append(change)
        try context.save()
        return next
    }
```

- [ ] **Step 4: Pusť testy — ověř že prochází**

Expected: 35 passed (30 + 5 nové).

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/Services/FeedingService.swift \
        Kojeni/KojeniTests/Services/FeedingServiceTests.swift
git commit -m "feat(services): FeedingService.switchBreast appends change to active session"
```

---

## Task 4: `FeedingService.endSession` + idempotence

**Files:**
- Modify: `Kojeni/Kojeni/Services/FeedingService.swift`
- Modify: `Kojeni/KojeniTests/Services/FeedingServiceTests.swift`

**Cíl:** End sezení nastaví `endedAt`. Idempotentní — druhé volání vrátí `nil` (no-op). Mezi voláními může `startSession` zase startovat.

- [ ] **Step 1: Napiš failing testy pro `endSession`**

Do `FeedingServiceTests`:

```swift
    // MARK: - endSession

    @Test func endSession_sets_endedAt() throws {
        let (service, _) = makeService()
        _ = try service.startSession(breast: .left)
        let when = Date(timeIntervalSinceReferenceDate: 50000)

        let ended = try service.endSession(at: when)

        #expect(ended?.endedAt == when)
        #expect(try service.activeSession() == nil)
    }

    @Test func endSession_returns_nil_when_no_active_session() throws {
        let (service, _) = makeService()
        let result = try service.endSession()
        #expect(result == nil)
    }

    @Test func endSession_is_idempotent() throws {
        let (service, _) = makeService()
        _ = try service.startSession(breast: .left)
        _ = try service.endSession()
        // Druhé end po skončení sezení — žádné aktivní, vrátí nil
        let second = try service.endSession()
        #expect(second == nil)
    }

    @Test func can_start_new_session_after_end() throws {
        let (service, _) = makeService()
        _ = try service.startSession(breast: .left)
        _ = try service.endSession()

        let next = try service.startSession(breast: .right)
        #expect(next.initialBreast == .right)
        #expect(next.isActive)
    }
```

- [ ] **Step 2: Pusť testy — ověř že selhávají**

Expected: 4 nové testy selžou.

- [ ] **Step 3: Implementuj `endSession`**

```swift
    /// Ukončí aktivní sezení. Idempotentní — no-op když nic neběží.
    @discardableResult
    func endSession(at date: Date = .now) throws -> FeedingSession? {
        guard let session = try activeSession() else { return nil }
        session.endedAt = date
        try context.save()
        return session
    }
```

- [ ] **Step 4: Pusť testy — ověř že prochází**

Expected: 39 passed (35 + 4 nové).

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/Services/FeedingService.swift \
        Kojeni/KojeniTests/Services/FeedingServiceTests.swift
git commit -m "feat(services): FeedingService.endSession idempotent"
```

---

## Task 5: `DiaperService` (pee/poo log)

**Files:**
- Create: `Kojeni/Kojeni/Services/DiaperService.swift`
- Create: `Kojeni/KojeniTests/Services/DiaperServiceTests.swift`

**Cíl:** Triviální služba pro insertování `DiaperEvent`. Oddělené od `FeedingService` — nemá invarianty na sezení.

- [ ] **Step 1: Napiš failing testy**

`Kojeni/KojeniTests/Services/DiaperServiceTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import Kojeni

@Suite @MainActor
struct DiaperServiceTests {

    private func makeService() -> (DiaperService, ModelContext) {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        return (DiaperService(context: context), context)
    }

    @Test func logPee_inserts_event_without_consistency() throws {
        let (service, context) = makeService()
        let when = Date(timeIntervalSinceReferenceDate: 1000)

        let event = try service.logPee(at: when)

        #expect(event.kind == .pee)
        #expect(event.consistency == nil)
        #expect(event.at == when)

        let all = try context.fetch(FetchDescriptor<DiaperEvent>())
        #expect(all.count == 1)
    }

    @Test func logPoo_inserts_event_with_consistency() throws {
        let (service, context) = makeService()
        let when = Date(timeIntervalSinceReferenceDate: 2000)

        let event = try service.logPoo(consistency: .normal, at: when)

        #expect(event.kind == .poo)
        #expect(event.consistency == .normal)
        #expect(event.at == when)

        let all = try context.fetch(FetchDescriptor<DiaperEvent>())
        #expect(all.count == 1)
    }

    @Test func logPoo_supports_all_consistencies() throws {
        let (service, context) = makeService()

        _ = try service.logPoo(consistency: .loose)
        _ = try service.logPoo(consistency: .normal)
        _ = try service.logPoo(consistency: .hard)

        let all = try context.fetch(FetchDescriptor<DiaperEvent>())
        #expect(all.count == 3)
        #expect(Set(all.compactMap { $0.consistency })
                == Set([.loose, .normal, .hard]))
    }
}
```

- [ ] **Step 2: Pusť testy — ověř že selhávají**

Expected: build fails — `Cannot find 'DiaperService' in scope`.

- [ ] **Step 3: Implementuj `DiaperService`**

`Kojeni/Kojeni/Services/DiaperService.swift`:

```swift
import Foundation
import SwiftData

@MainActor
final class DiaperService {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func logPee(at date: Date = .now) throws -> DiaperEvent {
        let event = DiaperEvent(at: date, kind: .pee)
        context.insert(event)
        try context.save()
        return event
    }

    @discardableResult
    func logPoo(consistency: PooConsistency, at date: Date = .now) throws -> DiaperEvent {
        let event = DiaperEvent(at: date, kind: .poo, consistency: consistency)
        context.insert(event)
        try context.save()
        return event
    }
}
```

- [ ] **Step 4: Pusť testy — ověř že prochází**

Expected: 42 passed (39 + 3 nové).

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/Services/DiaperService.swift \
        Kojeni/KojeniTests/Services/DiaperServiceTests.swift
git commit -m "feat(services): DiaperService logPee + logPoo"
```

---

## Task 6: `HomeView` přepnutí Idle / Active

**Files:**
- Modify: `Kojeni/Kojeni/Features/Home/HomeView.swift`
- Create: `Kojeni/Kojeni/Features/Home/IdleHomeView.swift` (zatím placeholder)
- Create: `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift` (zatím placeholder)

**Cíl:** `HomeView` pomocí `@Query` rozhodne, jestli ukázat `IdleHomeView` nebo `ActiveSessionView`. Placeholdery zatím — naplníme v dalších tasks. Žádné unit testy (SwiftUI state); ověřujeme smoke testem.

- [ ] **Step 1: Vytvoř placeholder `IdleHomeView`**

`Kojeni/Kojeni/Features/Home/IdleHomeView.swift`:

```swift
import SwiftUI

struct IdleHomeView: View {
    var body: some View {
        VStack {
            Text("Idle (placeholder)")
        }
    }
}

#Preview {
    IdleHomeView()
}
```

- [ ] **Step 2: Vytvoř placeholder `ActiveSessionView`**

`Kojeni/Kojeni/Features/Home/ActiveSessionView.swift`:

```swift
import SwiftUI

struct ActiveSessionView: View {
    let session: FeedingSession

    var body: some View {
        VStack {
            Text("Active (placeholder)")
            Text("Started: \(session.startedAt.formatted(.iso8601))")
        }
    }
}
```

- [ ] **Step 3: Přepiš `HomeView` aby branchovala**

`Kojeni/Kojeni/Features/Home/HomeView.swift`:

```swift
import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(filter: #Predicate<FeedingSession> { $0.endedAt == nil })
    private var activeSessions: [FeedingSession]

    var body: some View {
        NavigationStack {
            Group {
                if let session = activeSessions.first {
                    ActiveSessionView(session: session)
                } else {
                    IdleHomeView()
                }
            }
            .navigationTitle("Domů")
        }
    }
}

#Preview("Idle") {
    HomeView()
        .modelContainer(for: FeedingSession.self, inMemory: true)
}
```

- [ ] **Step 4: Build check**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination 'platform=iOS Simulator,id=E7D54495-1FBF-4E65-B7E4-F55D51806898' \
  -quiet 2>&1 | grep -E "error:" | head -5
```

Expected: žádný error.

- [ ] **Step 5: Smoke check na simulátoru**

```bash
SIMCTL=/Applications/Xcode.app/Contents/Developer/usr/bin/simctl
SIM_ID=E7D54495-1FBF-4E65-B7E4-F55D51806898

# Build do dedikovaného path + install
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath /tmp/kojeni-build -quiet
$SIMCTL install $SIM_ID /tmp/kojeni-build/Build/Products/Debug-iphonesimulator/Kojeni.app
$SIMCTL launch $SIM_ID cz.zapletal.Kojeni
sleep 3
$SIMCTL io $SIM_ID screenshot /tmp/kojeni-task6.png
```

Otevři `/tmp/kojeni-task6.png` — měl bys vidět onboarding (pokud čistá simulace) nebo `Idle (placeholder)` v tab `Domů` (pokud onboarding už proběhl).

- [ ] **Step 6: Pusť unit testy — nic se nesmí rozbít**

Expected: 42 passed (Plan 1 + Plan 2 service testy).

- [ ] **Step 7: Commit**

```bash
git add Kojeni/Kojeni/Features/Home
git commit -m "feat(ui): HomeView branches Idle/Active by @Query active session"
```

---

## Task 7: `IdleHomeView` — last feeding info + Kojit button + diaper section

**Files:**
- Modify: `Kojeni/Kojeni/Features/Home/IdleHomeView.swift`

**Cíl:** Idle stav HomeView má 3 části:
1. Hlavička s relativním časem od posledního ukončeného kojení („Poslední kojení: před 2h 14m" / „Zatím žádné kojení").
2. Velké tlačítko **Kojit** (otevírá BreastPickerSheet — UI tlačítka zatím jen ukáže sheet, sheet napíšeme v Task 8).
3. Sekce **Plenky** se dvěma tlačítky — Čůrání (instantní log přes `DiaperService.logPee`) a Kakání (otevře `DiaperSheet` — vytvoří Task 11; zatím placeholder sheet).

- [ ] **Step 1: Přepiš `IdleHomeView`**

`Kojeni/Kojeni/Features/Home/IdleHomeView.swift`:

```swift
import SwiftUI
import SwiftData

struct IdleHomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FeedingSession.endedAt, order: .reverse)
    private var allSessions: [FeedingSession]

    @State private var showBreastPicker = false
    @State private var showDiaperSheet = false

    private var lastEndedSession: FeedingSession? {
        allSessions.first { $0.endedAt != nil }
    }

    var body: some View {
        VStack(spacing: 24) {
            lastFeedingHeader
                .padding(.top)

            Spacer()

            Button(action: { showBreastPicker = true }) {
                Text("Kojit")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()

            diaperSection
                .padding(.bottom)
        }
        .sheet(isPresented: $showBreastPicker) {
            // BreastPickerSheet napíše Task 8.
            // Dočasný placeholder, ať jde sheet otevřít.
            Text("BreastPickerSheet (placeholder)")
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDiaperSheet) {
            // DiaperSheet napíše Task 11.
            Text("DiaperSheet (placeholder)")
                .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var lastFeedingHeader: some View {
        if let last = lastEndedSession, let endedAt = last.endedAt {
            VStack(spacing: 4) {
                Text("Poslední kojení")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(endedAt, style: .relative)
                    .font(.title3.monospacedDigit())
            }
        } else {
            Text("Zatím žádné kojení")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var diaperSection: some View {
        VStack(spacing: 12) {
            Text("Plenky")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(action: logPee) {
                    Label("Čůrání", systemImage: "drop.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.bordered)

                Button(action: { showDiaperSheet = true }) {
                    Label("Kakání", systemImage: "circle.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
    }

    private func logPee() {
        do {
            try DiaperService(context: modelContext).logPee()
        } catch {
            print("logPee failed: \(error)")
        }
    }
}

#Preview("Empty") {
    IdleHomeView()
        .modelContainer(for: [FeedingSession.self, DiaperEvent.self], inMemory: true)
}
```

- [ ] **Step 2: Build + spusť app na simulátoru, screenshot**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination 'platform=iOS Simulator,id=E7D54495-1FBF-4E65-B7E4-F55D51806898' \
  -derivedDataPath /tmp/kojeni-build -quiet
SIMCTL=/Applications/Xcode.app/Contents/Developer/usr/bin/simctl
SIM_ID=E7D54495-1FBF-4E65-B7E4-F55D51806898
$SIMCTL terminate $SIM_ID cz.zapletal.Kojeni 2>/dev/null
$SIMCTL install $SIM_ID /tmp/kojeni-build/Build/Products/Debug-iphonesimulator/Kojeni.app
$SIMCTL launch $SIM_ID cz.zapletal.Kojeni
sleep 3
$SIMCTL io $SIM_ID screenshot /tmp/kojeni-task7.png
```

Otevři `/tmp/kojeni-task7.png` — měl bys vidět:
- Hlavička „Zatím žádné kojení" (pokud čistá DB)
- Velké tlačítko **Kojit** uprostřed
- Dole Plenky se dvěma tlačítky **Čůrání** a **Kakání**

Stiskni Kojit → měl by se otevřít placeholder sheet „BreastPickerSheet (placeholder)".

- [ ] **Step 3: Pusť unit testy — nic se nesmí rozbít**

Expected: 42 passed.

- [ ] **Step 4: Commit**

```bash
git add Kojeni/Kojeni/Features/Home/IdleHomeView.swift
git commit -m "feat(ui): IdleHomeView with last-feeding header, Kojit button, diaper section"
```

---

## Task 8: `BreastPickerSheet` (L / P selection)

**Files:**
- Create: `Kojeni/Kojeni/Features/Home/BreastPickerSheet.swift`
- Modify: `Kojeni/Kojeni/Features/Home/IdleHomeView.swift` (nahradit placeholder)

**Cíl:** Sheet s dvěma velkými tlačítky **Levé** / **Pravé**. Default zvýrazněno opačné prso než to, kterým skončilo poslední sezení (per spec sekce 5 — alternuje od **posledního aktuálního** prsa minulého sezení). Pokud žádné předchozí, default je **levé**. Tap → `FeedingService.startSession(breast:)` + dismiss.

- [ ] **Step 1: Vytvoř `BreastPickerSheet`**

`Kojeni/Kojeni/Features/Home/BreastPickerSheet.swift`:

```swift
import SwiftUI
import SwiftData

struct BreastPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FeedingSession.endedAt, order: .reverse)
    private var allSessions: [FeedingSession]

    private var suggestedBreast: Breast {
        // Default: opačné než poslední aktivně použité prso minulého sezení.
        // Pokud žádné předchozí, default .left.
        guard let last = allSessions.first(where: { $0.endedAt != nil }) else {
            return .left
        }
        return last.currentBreast.opposite
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Které prso?")
                .font(.title2.bold())
                .padding(.top, 32)

            VStack(spacing: 16) {
                breastButton(for: .left)
                breastButton(for: .right)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.bottom)
        .presentationDetents([.medium])
    }

    private func breastButton(for breast: Breast) -> some View {
        Button(action: { start(with: breast) }) {
            Text(label(for: breast))
                .font(.system(size: 26, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 80)
        }
        .buttonStyle(suggestedBreast == breast ? .borderedProminent : .bordered)
        .controlSize(.large)
    }

    private func label(for breast: Breast) -> String {
        switch breast {
        case .left:  return "Levé"
        case .right: return "Pravé"
        }
    }

    private func start(with breast: Breast) {
        do {
            _ = try FeedingService(context: modelContext).startSession(breast: breast)
            dismiss()
        } catch {
            print("startSession failed: \(error)")
            dismiss()
        }
    }
}

#Preview {
    BreastPickerSheet()
        .modelContainer(for: [FeedingSession.self, BreastChange.self], inMemory: true)
}
```

- [ ] **Step 2: V `IdleHomeView` nahraď placeholder za `BreastPickerSheet()`**

V `Kojeni/Kojeni/Features/Home/IdleHomeView.swift` najdi:

```swift
        .sheet(isPresented: $showBreastPicker) {
            // BreastPickerSheet napíše Task 8.
            // Dočasný placeholder, ať jde sheet otevřít.
            Text("BreastPickerSheet (placeholder)")
                .presentationDetents([.medium])
        }
```

a nahraď za:

```swift
        .sheet(isPresented: $showBreastPicker) {
            BreastPickerSheet()
        }
```

- [ ] **Step 3: Smoke test**

Stejný build + install + launch jako Task 7. Screenshot do `/tmp/kojeni-task8.png`.

Manuálně v simulátoru (nebo otevři Simulator.app):
1. Tap **Kojit** → otevře se sheet „Které prso?" s tlačítky Levé / Pravé.
2. Tap **Levé** → sheet zmizí. HomeView by se měl přepnout na `ActiveSessionView` placeholder („Active (placeholder), Started: ...").

To znamená že `startSession` proběhl, vložil aktivní `FeedingSession`, `@Query` v `HomeView` ho zachytil a přepl branch.

- [ ] **Step 4: Pusť unit testy — nic se nesmí rozbít**

Expected: 42 passed.

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/Features/Home/BreastPickerSheet.swift \
        Kojeni/Kojeni/Features/Home/IdleHomeView.swift
git commit -m "feat(ui): BreastPickerSheet starts session with selected breast"
```

---

## Task 9: `ActiveSessionView` — timer + Stop + Switch

**Files:**
- Modify: `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift`

**Cíl:** Velký timer počítaný od `session.startedAt` přes `Text(timerInterval:)` — SwiftUI updatuje samo. Štítek aktuálního prsa (sleduje `session.currentBreast`). Dvě tlačítka: **Přehodit prso** (`switchBreast`) a **Stop** (`endSession`). Po Stop otevře `PumpedMlSheet` (vytvoří Task 10; zatím placeholder). Diaper section z `IdleHomeView` se NEukazuje (active sezení = focus na timer).

- [ ] **Step 1: Přepiš `ActiveSessionView`**

`Kojeni/Kojeni/Features/Home/ActiveSessionView.swift`:

```swift
import SwiftUI
import SwiftData

struct ActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext

    let session: FeedingSession

    @State private var showPumpedMlSheet = false
    @State private var endedSessionID: PersistentIdentifier?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Prso: \(label(for: session.currentBreast))")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(timerInterval: session.startedAt...Date.distantFuture,
                 countsDown: false)
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .monospacedDigit()

            Spacer()

            VStack(spacing: 12) {
                Button(action: switchBreast) {
                    Text("Přehodit prso")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(role: .destructive, action: endSession) {
                    Text("Stop")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .sheet(isPresented: $showPumpedMlSheet) {
            // PumpedMlSheet vznikne v Task 10.
            // Placeholder dokud sheet neexistuje:
            Text("PumpedMlSheet (placeholder)")
                .presentationDetents([.medium])
        }
    }

    private func label(for breast: Breast) -> String {
        switch breast {
        case .left:  return "Levé"
        case .right: return "Pravé"
        }
    }

    private func switchBreast() {
        do {
            _ = try FeedingService(context: modelContext).switchBreast()
        } catch {
            print("switchBreast failed: \(error)")
        }
    }

    private func endSession() {
        do {
            guard let ended = try FeedingService(context: modelContext).endSession()
            else { return }   // idempotent no-op — žádná sezení k ukončení
            endedSessionID = ended.persistentModelID
            showPumpedMlSheet = true
        } catch {
            print("endSession failed: \(error)")
        }
    }
}
```

- [ ] **Step 2: Build + smoke test**

Stejný build + install + launch postup jako Task 7/8.

Manuálně v simulátoru:
1. Pokud běží sezení (z Task 8), vidíš velký timer tikající od `startedAt`, „Prso: Levé", a tlačítka **Přehodit prso** a **Stop**.
2. Tap **Přehodit prso** → label se změní na „Prso: Pravé" (díky `@Query` + `currentBreast`). Timer pokračuje bez reset.
3. Tap **Stop** → otevře se placeholder sheet „PumpedMlSheet (placeholder)". `endedAt` se uložil, HomeView se po zavření sheet vrátí na IdleHomeView (protože už není aktivní sezení).
4. Zavři sheet swipem dolů → IdleHomeView s „Poslední kojení: před 0 s".

Screenshot do `/tmp/kojeni-task9.png`.

- [ ] **Step 3: Pusť unit testy — nic se nesmí rozbít**

Expected: 42 passed.

- [ ] **Step 4: Commit**

```bash
git add Kojeni/Kojeni/Features/Home/ActiveSessionView.swift
git commit -m "feat(ui): ActiveSessionView with running timer, switch + stop buttons"
```

---

## Task 10: `PumpedMlSheet` (post-stop ml entry)

**Files:**
- Create: `Kojeni/Kojeni/Features/PostFeed/PumpedMlSheet.swift`
- Modify: `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift` (nahradit placeholder)

**Cíl:** Sheet po Stop s Stepperem pro ml (0…300, krok 5, default 0). Tlačítka **Uložit** (zapíše do `session.pumpedMl`) a **Přeskočit** (zavře bez záznamu — `pumpedMl` zůstane `nil`). Sheet bere `PersistentIdentifier` ukončeného sezení a načte si ho přes `ModelContext`.

- [ ] **Step 1: Vytvoř `PumpedMlSheet`**

`Kojeni/Kojeni/Features/PostFeed/PumpedMlSheet.swift`:

```swift
import SwiftUI
import SwiftData

struct PumpedMlSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let sessionID: PersistentIdentifier

    @State private var ml: Int = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Odstříkané mléko")
                .font(.title2.bold())
                .padding(.top, 32)

            Text("Kolik ml jsi odstříkla po kojení?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Stepper(value: $ml, in: 0...300, step: 5) {
                Text("\(ml) ml")
                    .font(.system(size: 36, weight: .bold).monospacedDigit())
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button(action: save) {
                    Text("Uložit")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: skip) {
                    Text("Přeskočit")
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .presentationDetents([.medium])
    }

    private func save() {
        do {
            if let session = modelContext.model(for: sessionID) as? FeedingSession {
                session.pumpedMl = ml
                try modelContext.save()
            }
            dismiss()
        } catch {
            print("PumpedMlSheet save failed: \(error)")
            dismiss()
        }
    }

    private func skip() {
        dismiss()
    }
}
```

- [ ] **Step 2: Wire do `ActiveSessionView`**

V `Kojeni/Kojeni/Features/Home/ActiveSessionView.swift` najdi:

```swift
        .sheet(isPresented: $showPumpedMlSheet) {
            // PumpedMlSheet vznikne v Task 10.
            // Placeholder dokud sheet neexistuje:
            Text("PumpedMlSheet (placeholder)")
                .presentationDetents([.medium])
        }
```

a nahraď za:

```swift
        .sheet(isPresented: $showPumpedMlSheet) {
            if let id = endedSessionID {
                PumpedMlSheet(sessionID: id)
            }
        }
```

- [ ] **Step 3: Smoke test**

Stejný build + install + launch. V simulátoru:
1. Start sezení (Kojit → Levé).
2. Tap **Stop**.
3. Otevře se sheet „Odstříkané mléko" s Stepperem na 0 ml.
4. Nahodíme na 30 ml → tap **Uložit** → sheet zmizí, vidíme IdleHomeView.
5. (Verifikaci `pumpedMl == 30` lze udělat v Plan 5 v HistoryView. Zatím smoke = sheet ukládá bez crashe.)

Screenshot do `/tmp/kojeni-task10.png`.

- [ ] **Step 4: Pusť unit testy — nic se nesmí rozbít**

Expected: 42 passed.

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/Features/PostFeed/PumpedMlSheet.swift \
        Kojeni/Kojeni/Features/Home/ActiveSessionView.swift
git commit -m "feat(ui): PumpedMlSheet after Stop, saves to session.pumpedMl"
```

---

## Task 11: `DiaperSheet` (kakání consistency)

**Files:**
- Create: `Kojeni/Kojeni/Features/PostFeed/DiaperSheet.swift`
- Modify: `Kojeni/Kojeni/Features/Home/IdleHomeView.swift` (nahradit placeholder)

**Cíl:** Sheet se 3 velkými tlačítky pro konzistenci (Řídké / Normální / Tvrdé). Tap → `DiaperService.logPoo(consistency:)` + dismiss.

- [ ] **Step 1: Vytvoř `DiaperSheet`**

`Kojeni/Kojeni/Features/PostFeed/DiaperSheet.swift`:

```swift
import SwiftUI
import SwiftData

struct DiaperSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Kakání — konzistence")
                .font(.title2.bold())
                .padding(.top, 32)

            VStack(spacing: 12) {
                consistencyButton(.loose,  label: "Řídké")
                consistencyButton(.normal, label: "Normální")
                consistencyButton(.hard,   label: "Tvrdé")
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.bottom)
        .presentationDetents([.medium])
    }

    private func consistencyButton(_ consistency: PooConsistency, label: String) -> some View {
        Button(action: { log(consistency: consistency) }) {
            Text(label)
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 70)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func log(consistency: PooConsistency) {
        do {
            _ = try DiaperService(context: modelContext).logPoo(consistency: consistency)
            dismiss()
        } catch {
            print("logPoo failed: \(error)")
            dismiss()
        }
    }
}

#Preview {
    DiaperSheet()
        .modelContainer(for: DiaperEvent.self, inMemory: true)
}
```

- [ ] **Step 2: V `IdleHomeView` nahraď placeholder za `DiaperSheet()`**

V `Kojeni/Kojeni/Features/Home/IdleHomeView.swift` najdi:

```swift
        .sheet(isPresented: $showDiaperSheet) {
            // DiaperSheet napíše Task 11.
            Text("DiaperSheet (placeholder)")
                .presentationDetents([.medium])
        }
```

a nahraď za:

```swift
        .sheet(isPresented: $showDiaperSheet) {
            DiaperSheet()
        }
```

- [ ] **Step 3: Smoke test**

Stejný build + install + launch. V simulátoru:
1. Na IdleHomeView tap **Kakání** → otevře se sheet se 3 tlačítky.
2. Tap **Normální** → sheet zmizí, do DB se uložil `DiaperEvent(kind: .poo, consistency: .normal)`.
3. Tap **Čůrání** na IdleHomeView → instant log (žádný sheet). Verifikace v Plan 5 v HistoryView.

Screenshot do `/tmp/kojeni-task11.png`.

- [ ] **Step 4: Pusť unit testy — nic se nesmí rozbít**

Expected: 42 passed.

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/Features/PostFeed/DiaperSheet.swift \
        Kojeni/Kojeni/Features/Home/IdleHomeView.swift
git commit -m "feat(ui): DiaperSheet for kakání consistency selection"
```

---

## Task 12: End-to-end smoke + CHANGELOG

**Files:**
- Modify: `CHANGELOG.md`
- (Žádný nový kód — jen ověření.)

**Cíl:** Projít celý feeding flow ručně v simulátoru, ověřit happy path + edge case (přepnutí prsa během sezení), zapsat změny do CHANGELOG.

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

- [ ] **Step 2: Smoke checklist (manuálně, otevři Simulator.app)**

Projdi tyhle kroky v simulátoru a odškrtni:

- [ ] OnboardingSheet ukázal (default interval 3 h) → Hotovo.
- [ ] HomeView Idle: „Zatím žádné kojení", tlačítko **Kojit**, sekce Plenky.
- [ ] Tap **Kojit** → BreastPickerSheet ukáže „Které prso?" s Levé / Pravé.
- [ ] Tap **Levé** → sheet zmizí, vidím ActiveSessionView s tikajícím timerem, „Prso: Levé".
- [ ] Tap **Přehodit prso** → label „Prso: Pravé", timer pokračuje bez restartu.
- [ ] Tap **Přehodit prso** ještě jednou → „Prso: Levé".
- [ ] Tap **Stop** → PumpedMlSheet ukáže Stepper na 0 ml.
- [ ] Nastav 25 ml → **Uložit** → sheet zmizí, vidím IdleHomeView „Poslední kojení: před … s".
- [ ] Spusť další sezení **Kojit** → default-vybrané by mělo být **Pravé** (opačné než poslední `currentBreast == .left`).
- [ ] **Stop** → PumpedMlSheet → **Přeskočit** → IdleHomeView aktualizovaný čas.
- [ ] Tap **Čůrání** → žádný sheet, instantní log (vidíme jen že nic nespadlo).
- [ ] Tap **Kakání** → DiaperSheet → tap **Normální** → sheet zmizí.
- [ ] Quit app (⌘ shift H × 2 + swipe). Znovu launch. Onboarding **NE**ukáže (AppSettings existuje). HomeView se otevře v Idle stavu (poslední sezení už skončilo).

Pokud kterýkoliv krok selže, zkonzultuj a oprav před commitnutím.

- [ ] **Step 3: Pusť unit testy — finální verifikace**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination 'platform=iOS Simulator,id=E7D54495-1FBF-4E65-B7E4-F55D51806898' \
  -quiet 2>&1 | grep -c "passed"
```

Expected: **42** (25 z Plan 1 + 17 nových z Plan 2: Task 1 = 1, Task 2 = 4, Task 3 = 5, Task 4 = 4, Task 5 = 3).

- [ ] **Step 4: Update `CHANGELOG.md`**

Před existující `## [0.1.0]` přidej:

```markdown
## [0.2.0] — Plan 2: Feeding core — 2026-06-06

- `FeedingService` se startSession (s invariantem žádných 2 aktivních), switchBreast (alternuje), endSession (idempotentní).
- `DiaperService` s logPee a logPoo (s konzistencí).
- HomeView se přepíná mezi `IdleHomeView` (Kojit + Plenky) a `ActiveSessionView` (timer + Stop + Přehodit prso) na základě `@Query` aktivních sezení.
- `BreastPickerSheet` po Kojit, default zvýrazněno opačné prso než minulé sezení.
- `PumpedMlSheet` po Stop pro záznam ml (default 0, Stepper krok 5).
- `DiaperSheet` po Kakání pro výběr konzistence (Řídké / Normální / Tvrdé).
- 17 nových Swift Testing testů pro služby, vše zelené (42 celkem).

```

- [ ] **Step 5: Commit + tag**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for Plan 2 feeding core"
git tag -a v0.2.0 -m "Plan 2 (Feeding core) complete"
```

---

## Hotovo — Plan 2 dokončen

Stav po Plan 2:
- Mamka může reálně používat appku: start kojení (s výběrem prsa), přepínat během sezení, ukončit s případným záznamem ml, logovat pleny.
- Vše perzistuje v SwiftData. UI reaguje na DB stav přes `@Query`.
- Bez Live Activity (Plan 3) a notifikací (Plan 4) — Stop musí proběhnout přímo v appce.
- Žádná Historie zatím (Plan 5) — data se nahromaďují v DB nepozorovaně.

**Plán 3 (Live Activity) staví na:** `FeedingService` (zavolá ho App Intent z Lock Screen tlačítka), `FeedingSession.startedAt` (timer reference), `currentBreast` (display).
