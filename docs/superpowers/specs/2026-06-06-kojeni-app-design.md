# Kojení — design spec

**Datum:** 2026-06-06
**Autor:** Patrik Zapletal
**Stav:** Návrh ke schválení

iOS aplikace pro maminku po porodu — sledování kojení (stopky, levé/pravé prso, odstříknuté mléko) a plenkových událostí (čůrání/kakání), s živým timerem na Lock Screen (Live Activity) a lokálními notifikacemi připomínajícími další kojení.

## 1. Scope

### Funkční rozsah

1. **Trackování kojení** — stopky se startem/stopem, výběr prsa L/P, přepínání prsa během jednoho sezení (timer pokračuje, ukládá se jen událost přepnutí), po Stop volitelný záznam odstříknutého mléka v ml.
2. **Trackování plenek** — rychlý záznam: čas + typ (čůrání / kakání), u kakání i konzistence (řídké / normální / tvrdé).
3. **Live Activity** — viditelný timer na Lock Screen + Dynamic Island, s tlačítky „Stop" a „Přehodit prso" bez nutnosti odemykat telefon.
4. **Připomínky kojení** — lokální notifikace na čas (`konec_posledního_kojení + zvolený_interval`). Akce v notifikaci: „Odložit 15 min", „Odložit 30 min", „Krmím teď".
5. **Historie** — 4 pohledy: dnešní timeline (24h), týdenní graf, chronologický seznam s editací, souhrnné statistiky.
6. **Onboarding** — jediná otázka při prvním spuštění: výchozí interval reminderů.

### Vědomě mimo scope

- Sledování spánku, váhy, výšky, očkování, návštěv lékaře.
- Více miminek.
- Více uživatelů, cloud sync, sdílení dat mezi zařízeními.
- Apple Watch companion.
- Apple Health export / import.
- Jiné jazyky než čeština.
- iPad layout, landscape orientace.

### Cílový uživatel

Jedna maminka, jeden iPhone, vše lokálně. Příští rozšíření (App Store, více uživatelů) neřešíme — design ale nesmí znemožnit budoucí přechod (např. žádné singletony bránící DI).

## 2. Architektura a tech stack

### Stack

| Vrstva | Volba | Poznámka |
|---|---|---|
| Jazyk | Swift 6+ | |
| IDE | Xcode 26+ | |
| UI | SwiftUI | Deklarativně, žádný UIKit. |
| Persistence | SwiftData | Na pozadí SQLite. |
| Live Activity | ActivityKit + WidgetKit | Widget Extension target. |
| Notifikace | UserNotifications | Lokální, s akčními tlačítky. |
| Graf | Swift Charts | Nativní. |
| Akce v Live Activity | App Intents | Volá se i když app neběží. |

**Minimální iOS:** **26.5**. Cílíme jen na maminčin iPhone, který tuto verzi má — žádný důvod podporovat starší. Všechny použité API (SwiftData, ActivityKit, App Intents, Swift Charts) jsou v 26.5 dostupné nativně.

**Cílové zařízení:** jen iPhone, portrét only. Žádný iPad layout.

### Distribuce

**AltStore / SideStore** s 7denním re-sign přes WiFi. Free Apple ID, žádný Apple Developer Program. Akceptovaná nepohodlnost: Mac musí být zapnutý a na stejné WiFi alespoň jednou za 7 dnů, jinak appka přestane fungovat.

Vývoj probíhá na vývojářově iPhone přes Xcode (free provisioning). Build pro maminku se přenese přes AltStore.

### Struktura projektu

Xcode workspace s 2 targety (main app + widget extension) + 1 test target:

```
kojeni-app/
├── Kojeni.xcworkspace
├── Kojeni/                          ← main app target
│   ├── App/
│   │   └── KojeniApp.swift          ← @main, SwiftData container setup
│   ├── Models/                      ← SwiftData @Model třídy
│   │   ├── FeedingSession.swift
│   │   ├── BreastChange.swift
│   │   ├── DiaperEvent.swift
│   │   ├── AppSettings.swift
│   │   └── Enums.swift              ← Breast, DiaperKind, PooConsistency
│   ├── Features/
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── ActiveSessionView.swift
│   │   │   ├── IdleHomeView.swift
│   │   │   └── BreastPickerSheet.swift
│   │   ├── History/
│   │   │   ├── HistoryView.swift
│   │   │   ├── TodayTimelineView.swift
│   │   │   ├── WeeklyChartView.swift
│   │   │   ├── SessionListView.swift
│   │   │   ├── StatisticsView.swift
│   │   │   └── EditSessionSheet.swift
│   │   ├── Settings/
│   │   │   └── SettingsView.swift
│   │   ├── Onboarding/
│   │   │   └── OnboardingSheet.swift
│   │   └── PostFeed/
│   │       ├── PumpedMlSheet.swift
│   │       └── DiaperSheet.swift
│   ├── Services/
│   │   ├── FeedingService.swift     ← start, switchBreast, endSession
│   │   ├── ReminderScheduler.swift  ← obal nad UNUserNotificationCenter
│   │   └── LiveActivityManager.swift
│   ├── AppIntents/
│   │   ├── SwitchBreastIntent.swift ← Live Activity tlačítko
│   │   └── StopFeedingIntent.swift  ← Live Activity tlačítko
│   ├── SharedAttributes/
│   │   └── FeedingAttributes.swift  ← ActivityAttributes (sdílené s widgetem)
│   └── Resources/
│       ├── Assets.xcassets
│       └── cs.lproj/Localizable.strings
├── KojeniWidget/                    ← Widget Extension target
│   ├── FeedingLiveActivity.swift    ← UI Live Activity
│   └── KojeniWidgetBundle.swift
├── KojeniTests/                     ← unit + integration testy
│   ├── Models/
│   ├── Services/
│   └── Helpers/
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-06-06-kojeni-app-design.md  ← tento dokument
```

### Datový tok

```
Tap "Kojit" → BreastPickerSheet → user picks .left
   ↓
FeedingService.startSession(breast: .left, at: .now)
   ↓
   ├─ Validace: žádné aktivní sezení v DB → throws SessionAlreadyActiveError
   ├─ Insert FeedingSession(startedAt: now, initialBreast: .left)
   ├─ LiveActivityManager.start(session) → Live Activity na Lock Screen
   └─ ReminderScheduler.cancelPending()  ← smaže předchozí reminder, kdyby byl

[mamka tapne "Přehodit prso" v Live Activity]
   ↓
SwitchBreastIntent → FeedingService.switchBreast()
   ↓
   ├─ append BreastChange(at: now, to: opposite) k aktivnímu sezení
   ├─ LiveActivityManager.updateBreast(to: opposite)
   └─ Timer NEPŘERUŠÍ — Live Activity ukazuje stále čas od session.startedAt

[mamka tapne "Stop" v Live Activity]
   ↓
StopFeedingIntent → FeedingService.endSession()
   ↓
   ├─ Validace: existuje aktivní sezení? → jinak no-op (idempotence)
   ├─ session.endedAt = now
   ├─ LiveActivityManager.end()
   ├─ Otevře hlavní app (App Intent flag .opensAppWhenRun = true) a routne na PumpedMlSheet.
   │  Pokud uživatel app neotevře (např. zruší unlock), PumpedMlSheet se ukáže
   │  při příštím otevření appky, dokud session.pumpedMl není vyplněn ani explicit-skip.
   ├─ User zadá ml nebo skipne → session.pumpedMl (Int? — nil zůstává jen pokud sheet zatím neviděl)
   └─ ReminderScheduler.scheduleAfter(session.endedAt + interval)
```

### Klíčové principy

- **Services jsou stateless** kromě závislosti na `ModelContext` (DI přes `@Environment`).
- **Žádný singleton** typu `.shared` — bránilo by testování a budoucímu rozšíření.
- **Žádný backend, žádný cloud** — vše lokální v SwiftData store.
- **Live Activity ID není uložené v DB** — žije v paměti `LiveActivityManager`. Při restartu se na běžící sezení napojíme přes `Activity<FeedingAttributes>.activities` (iOS samo přežije restart).

## 3. Datový model

### SwiftData entity

```swift
@Model
final class FeedingSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?                  // nil = aktivní; max 1 aktivní v DB
    var initialBreast: Breast
    var pumpedMl: Int?                  // nil = nezadáno

    @Relationship(deleteRule: .cascade, inverse: \BreastChange.session)
    var breastChanges: [BreastChange] = []

    init(startedAt: Date, initialBreast: Breast) {
        self.id = UUID()
        self.startedAt = startedAt
        self.initialBreast = initialBreast
    }

    var isActive: Bool { endedAt == nil }
    var duration: TimeInterval { (endedAt ?? .now).timeIntervalSince(startedAt) }
    var currentBreast: Breast {
        breastChanges.sorted { $0.at < $1.at }.last?.to ?? initialBreast
    }
}

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

@Model
final class DiaperEvent {
    var id: UUID
    var at: Date
    var kind: DiaperKind
    var consistency: PooConsistency?    // vyplněno právě když kind == .poo

    init(at: Date, kind: DiaperKind, consistency: PooConsistency? = nil) {
        self.id = UUID()
        self.at = at
        self.kind = kind
        self.consistency = consistency
    }
}

@Model
final class AppSettings {
    var reminderIntervalMinutes: Int    // default 180
    var remindersEnabled: Bool          // default true

    init(reminderIntervalMinutes: Int = 180, remindersEnabled: Bool = true) {
        self.reminderIntervalMinutes = reminderIntervalMinutes
        self.remindersEnabled = remindersEnabled
    }
}

enum Breast: String, Codable {
    case left = "L", right = "R"
    var opposite: Breast { self == .left ? .right : .left }
}

enum DiaperKind: String, Codable {
    case pee, poo
}

enum PooConsistency: String, Codable {
    case loose, normal, hard
}
```

### Invarianty

- V DB může být **maximálně 1 aktivní `FeedingSession`** (`endedAt == nil`). Hlídá `FeedingService.startSession`, validuje fetchem před insertem.
- `BreastChange.to` musí být **opačné** než dosavadní aktuální prso v sezení. Hlídá `FeedingService.switchBreast`.
- `DiaperEvent.consistency` je vyplněno **právě tehdy, když `kind == .poo`**. Hlídá UI form, ale validuje se i v `DiaperEvent.init`.
- `AppSettings.reminderIntervalMinutes` v rozsahu **30…360** (validuje Stepper v UI).
- `AppSettings` má v DB právě jeden řádek; první spuštění ho vytvoří s defaulty.

### Odvozená data (nepatří do DB)

```swift
extension FeedingSession {
    /// Rozdělí sezení na segmenty podle BreastChange událostí.
    /// Použito v Timeline / Detail view.
    func segments() -> [(breast: Breast, start: Date, end: Date)]
}
```

### Migrace

Schema v1. Pro budoucí změny (např. přidání váhy, sleep tracking) použijeme `SchemaMigrationPlan` se `VersionedSchema`. Tohle není MVP scope.

## 4. UI

### Navigační struktura

```
RootView (TabView, 3 tabs)
├── 🏠 Domů (HomeView)
├── 📊 Historie (HistoryView se segmented control: Dnes | Týden | Seznam | Statistiky)
└── ⚙ Nastavení (SettingsView)

Modálně jako sheety:
- OnboardingSheet  ← jen poprvé, fullscreen
- BreastPickerSheet  ← po tapu "Kojit", půl-výška
- PumpedMlSheet  ← po Stop kojení, půl-výška
- DiaperSheet  ← po tapu kakání (konzistence), půl-výška
- EditSessionSheet  ← z Historie, plná výška
```

### HomeView — hlavní obrazovka

Dva stavy podle `existuje aktivní FeedingSession?`.

**Idle (kojení neběží):**
- Hlavička: „Poslední kojení: před 2h 14m" (relativní čas; chybí-li historie: „Zatím žádné kojení").
- Velké tlačítko **„Kojit"** (~70% šířky, 80pt vysoké, primary tint).
- Pod tím sekce **Plenky** se dvěma tlačítky: „💧 Čůrání" (instantní záznam) a „💩 Kakání" (otevře DiaperSheet pro konzistenci).

**Aktivní (kojení běží):**
- Velký timer počítaný od `session.startedAt` (přes `Text(timerInterval:)` — SwiftUI updatuje samo).
- Štítek „Prso: L" / „Prso: P".
- Dvojice tlačítek: **„Přehodit prso"**, **„Stop"** (Stop je destructive tint).
- Plenkové tlačítka dál dostupná dole.

### Live Activity (Lock Screen + Dynamic Island)

```
Lock Screen (rozšířená):              Dynamic Island (compact):
┌────────────────────────────┐        ┌────────┐
│ 🤱 Kojení • Prso: P         │        │P 18:42│
│ 00:18:42                    │        └────────┘
│                              │
│ [Přehodit prso] [Stop]      │        Dynamic Island (expanded):
└────────────────────────────┘        ┌──────────────────────────┐
                                       │🤱 P • 00:18:42           │
                                       │[Přehodit] [Stop]         │
                                       └──────────────────────────┘
```

Tlačítka volají App Intents (`SwitchBreastIntent`, `StopFeedingIntent`). Timer je `Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)` — SwiftUI updatuje text bez stálého background tasku.

### HistoryView — 4 podpohledy přes Segmented Picker

1. **Dnes (timeline)** — vertikální timeline 24h, eventy na časové ose, různé barvy podle typu. Tap → detail. Long-press → smazat / upravit.
2. **Týden (graf)** — Swift Charts stacked bar chart: X = dny týdne, Y = celkové minuty kojení, barvy = L vs P. Nahoře přepínač metrik (Délka kojení / Počet plenek).
3. **Seznam** — chronologický scroll list, sekce po dnech. Každý řádek: čas + ikona + délka/objem. Tap → EditSessionSheet.
4. **Statistiky** — karty: ⌀ kojení/den, ⌀ délka, ⌀ interval mezi kojeními, ⌀ plenek/den, suma ml/týden.

### SettingsView

- Stepper: interval reminderu (rozsah 30…360 min, krok 15 min, default 180).
- Toggle: připomínky zapnuté.
- Sekce „O aplikaci": verze, build, tlačítko pro otevření iOS Settings (pro povolení notifikací, pokud denied).

### OnboardingSheet (jednou)

- Krátká uvítací stránka + jeden Stepper pro výchozí interval.
- Tlačítko „Hotovo" → uloží do `AppSettings`, sheet zmizí.

### Designová pravidla

- **Velká tlačítka** (min 60×60 pt) — mamka kojí jednou rukou.
- **Čeština všude** (`Localizable.strings` v `cs`).
- **Haptic feedback** na Start / Stop / Switch.
- **Animace ≤ 200 ms** — appka musí být svižná i v 3:00 ráno.
- **Tmavý mód podporován** (SwiftUI nativně).

## 5. Notifikace a Live Activity

### ReminderScheduler

**Implementace** přes `UNUserNotificationCenter`. Lokální notifikace, žádný server.

**Kdy se reminder plánuje:**
- **Konec kojení** (`endSession`) → notifikace na `endedAt + reminderIntervalMinutes`.
- **Start kojení** (`startSession`) → cancel pending reminder.
- **Snooze tap** z notifikace → cancel původní, schedule nová na `now + snoozeMinutes`.
- **Změna intervalu v Nastavení** → pokud pending reminder existuje, přeplánuje na `lastSession.endedAt + nový_interval`. Pokud takto vypočtený čas leží už v minulosti (interval byl výrazně zkrácen), notifikace se doručí **okamžitě** (UNNotificationCenter s `trigger == nil` to udělá automaticky).
- **Vypnutí remindrů v Nastavení** → cancel pending, dál nic neplánuje.

**Identifier:** všechny reminder notifikace mají identifier `"feeding-reminder"`. Vždy maximálně 1 v queue, snadné rušení přes `removePendingNotificationRequests(withIdentifiers: ["feeding-reminder"])`.

### Obsah notifikace

```
Title: 🤱 Čas na kojení
Body:  Od posledního krmení uběhly 3 hodiny.
Categories: feeding-reminder-category
Actions:
  ▶ Krmím teď   (identifier: "feeding-now-action", foreground)
  ⏰ Odložit 15 min  (identifier: "snooze-15-action", background)
  ⏰ Odložit 30 min  (identifier: "snooze-30-action", background)
```

### Action handling

V `AppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)`:
- `feeding-now-action` → otevře app, zavolá `FeedingService.startSession(breast: lastSession.initialBreast.opposite)`. Pokud žádné předchozí sezení neexistuje, default je `.left`. Pokud byly v posledním sezení přepnutí prsa, alternuje od **posledního** prsa, ne od initial — tedy `session.currentBreast.opposite`.
- `snooze-15-action` / `snooze-30-action` → cancel pending, schedule nový reminder za 15 / 30 min. App se neotvírá.
- Default (tap mimo akci) → otevře app na HomeView.

### Permissions

Při dokončení onboardingu (nebo při prvním Start kojení, pokud onboarding přeskočen) → `requestAuthorization([.alert, .sound, .badge])`. Pokud denied: HomeView ukáže nenápadný banner „Reminder nefunguje — zapni notifikace v Nastaveních [→]" s tlačítkem otevírajícím iOS Settings stránku appky.

### LiveActivityManager

Životní cyklus jedné Live Activity = jedno sezení.

**Start:** `Activity<FeedingAttributes>.request(...)`. Vrácený `Activity.id` se uloží do paměti služby (ne do SwiftData — žije jen v rámci běhu). Při restartu app se na běžící Live Activity napojíme přes `Activity<FeedingAttributes>.activities.first { ... }`.

**Update (přepnutí prsa):** `activity.update(using: FeedingAttributes.ContentState(currentBreast: ...))`. Timer na obrazovce **dál tiká od `startedAt`** — pole je `Text(timerInterval:)`, SwiftUI updatuje samo.

**End:** `activity.end(dismissalPolicy: .immediate)`.

Pokud `ActivityAuthorizationInfo().areActivitiesEnabled == false` (Low Power Mode, iOS Settings off): nestartuje LA, jen ukáže timer v app. Sezení funguje normálně.

### Edge cases

| Situace | Chování |
|---|---|
| App force-quit během kojení | Live Activity běží dál (samostatný proces). SwiftData záznam uložen. Při příštím otevření app: HomeView ukáže „kojení běží" s timerem od `startedAt`. |
| Restart telefonu během kojení | Live Activity přežije (iOS feature). SwiftData taky. Po restartu app se chytne na běžící sezení. |
| Stop v Live Activity, app crashne před doplněním ml | Sezení uložené s `endedAt`, `pumpedMl == nil`. V Historii lze dodatečně doplnit přes EditSessionSheet. Žádná ztráta dat. |
| Reminder doručen během běžícího kojení (race) | `startSession()` volá `cancelPending` jako první. Při race < 1s tap na „Krmím teď" detekuje aktivní sezení a vrátí no-op + toast „Kojení už běží". |
| Dvojí Stop v Live Activity | `endSession()` je idempotentní — pokud sezení už má `endedAt`, druhé volání no-op. |
| Live Activity 8h iOS limit | Po 8h iOS ji ukončí. Při otevření app: pokud sezení běží > 8h, ukáže banner „Pozor: sezení běží více než 8h, zkontroluj a uprav". |
| Permissions denied později povolené | Settings → „Povolit notifikace" → otevře iOS Settings stránku appky. |
| Sezení > 12h s `endedAt == nil` při startu app | Dialog „Zdá se, že kojení trvá X h. Bylo to opravdu tak dlouhé, nebo zapomněl/a Stop?" → [Uložit] / [Zrušit sezení]. |

## 6. Testování a error handling

### Testovací strategie

**Unit testy (XCTest):**
- **Modely:** `FeedingSession.duration`, `currentBreast`, derived `segments()` z `breastChanges`.
- **FeedingService:** `startSession`, `switchBreast`, `endSession` proti in-memory `ModelContainer`. Invarianty: žádná 2 aktivní sezení, switch změní prso na opačné, `endSession` idempotentní.
- **ReminderScheduler:** mockujeme `UNUserNotificationCenter` přes protokol. Ověříme `scheduleAfter`, `cancelPending`, snooze přeplánování.
- **Statistiky:** výpočty proti seedovaným datům.

**Integration testy:**
- **SwiftData round-trip:** založit Session + BreastChange + DiaperEvent, znovu otevřít `ModelContainer`, načíst, ověřit shodu.
- **Notifikace + service:** start kojení → cancel pending; konec → schedule pending. (Mocked notification center.)

**Manual smoke checklist (před releasem):**
- [ ] Live Activity se zobrazí na Lock Screen + Dynamic Island, timer tiká.
- [ ] Tap „Přehodit" v Live Activity změní prso bez resetu timeru.
- [ ] Notifikace se objeví v očekávaný čas.
- [ ] Snooze a „Krmím teď" akce fungují z notifikace.
- [ ] App force-quit nezastaví Live Activity.
- [ ] Restart telefonu během kojení — Live Activity přežije.

**Code coverage cíl:** ≥ **70 %** na `Models/` + `Services/`. UI views nepokrýváme unit testy.

### Error handling

Princip: appka **nikdy nepadne**, vždy degraduje na funkční stav. Žádné `try!` v produkčním kódu (kromě testů).

| Chyba | Reakce |
|---|---|
| SwiftData uložení selže | Logovat (`OSLog`), banner „Nepodařilo se uložit, zkus znovu". Sezení v paměti zůstane, lze Stop znovu. |
| Notification permission denied | Banner na HomeView s tlačítkem pro otevření iOS Settings. Reminder se neplánuje, ostatní funguje. |
| Live Activity nedostupná | Sezení funguje, jen bez Lock Screen UI. Timer v app dál tiká. |
| App Intent z Live Activity selže | No-op + log. Mamka může otevřít app a stopnout ručně. |
| Reminder interval `nil` / 0 | Fallback 180 min. UI Stepper validuje rozsah 30…360. |
| `breastChanges` s duplicitním timestampem | Stable sort by `at`, při shodě zachová insertion order. |
| Sezení > 12h bez `endedAt` při startu app | Dialog „Zapomenuté sezení?" → [Uložit] / [Zrušit]. |

**Logging:** `Logger` z `os` framework, subsystem `cz.zapletal.kojeni`. Žádné PII v lozích.

**Crash reporting:** nic externího. Pokud něco selže, debug přes Xcode console při dalším AltStore connect.

## 7. Otevřené body

Nic blokujícího implementaci. Případné rozšíření po MVP:

- Apple Health export kojení a plenek.
- Sleep tracking.
- Apple Watch companion.
- Více miminek.
- Sdílení s partnerem přes CloudKit.

## 8. Definice hotovo (Definition of Done) pro MVP

- Všech 6 funkčních scope bodů (sekce 1) implementováno.
- Unit + integration testy s coverage ≥ 70 % na Models + Services.
- Manual smoke checklist celý odškrtnutý.
- App nainstalovaná na maminčiným iPhonu přes AltStore, ověřena 1 týden reálného používání.
- Žádný známý crash, žádný známý data-loss bug.
