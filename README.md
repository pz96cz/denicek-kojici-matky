# Deníček kojicí matky

iOS aplikace pro maminku po porodu — sledování kojení (stopky, levé/pravé prso, odstříknuté mléko), plenkových událostí a poznámek; s živým timerem na Lock Screen (Live Activity) a lokálními notifikacemi připomínajícími další kojení.

Postavená jako osobní projekt pro jednu konkrétní mamku, distribuovaná přes AltStore (žádný App Store, žádný placený Apple Developer Program).

> *iOS app for tracking breastfeeding sessions with Live Activity, local reminder notifications, and diary entries. Designed for one mom, distributed via AltStore.*

---

## Funkce

### Hlavní obrazovka

- **Karta posledního kojení** — čas (HH:mm – HH:mm), délka, proporcionální bary pro levé/pravé prso v daném sezení
- **„Další kojení"** — kdy by mělo přijít další (`endedAt + interval`)
- Karty plenek **dnes**: čůrání + kakání s počtem a časem posledního záznamu

### Běžící sezení

- Velký timer počítaný od `startedAt` (auto-updating)
- Color badge aktuálního prsa (modré L / fialové P)
- **Live progress card** — kolik vteřin každé prso (update každou sekundu)
- Inline karty **Poznámka** a **Odstříknuto** — během sezení doplnitelné
- Tlačítka **Přehodit prso** / **Stop**

### Live Activity (Lock Screen + Dynamic Island)

- Tikající timer na Lock Screen + Dynamic Island
- Color badge prsa s plným názvem
- Tlačítka **Přehodit prso** / **Stop**
- Tap **Stop** otevře app → automaticky PumpedMlSheet pro doplnění ml

### Lokální notifikace

- Schedule po Stop sezení podle nastaveného intervalu (30–360 min)
- Akce v notifikaci: **Krmím teď** / **Odložit 15 min** / **Odložit 30 min**
- Při „Krmím teď" se app otevře a sezení autostartne s opačným prsem

### Historie

- **Dnes** — 24h vertikální timeline (sezení jako modré boxy, plenky jako tečky)
- **Týden** — Swift Charts side-by-side bary (Levé/Pravé prso, Čůrání/Kakání)
- **Seznam** — chronologický scroll grupovaný po dnech (sezení + plenky dohromady)
- **Statistiky** — 9 karet ve 2 sekcích (Kojení + Vyprázdňování)
- **EditSessionSheet** — úprava všeho (čas, prso, ml, poznámka) + delete s confirmation

### Nastavení

- Interval reminderů (30–360 min, krok 15)
- Toggle reminders zapnuté
- Banner v IdleHomeView pokud iOS notifikace zakázány
- Verze + Build + tlačítko otevřít iOS Settings notifikací

---

## Tech stack

- **Swift 6+**, Xcode 26+
- **iOS 26.1+** (minimum deployment)
- **SwiftUI** + **SwiftData** (žádný UIKit, žádný Core Data)
- **ActivityKit** + **WidgetKit** (Live Activity)
- **App Intents** (Lock Screen tlačítka)
- **UserNotifications** (lokální notifikace + akce)
- **Swift Charts** (týdenní graf)
- **Swift Testing** (testovací framework, ne XCTest)
- Žádné externí dependency

### Struktura projektu

```
Kojeni/
├── Kojeni.xcodeproj
├── Kojeni/                          ← main app target
│   ├── KojeniApp.swift              ← @main, ModelContainer setup
│   ├── App/RootView.swift           ← TabView + scenePhase pickup
│   ├── Models/                      ← @Model entity (SwiftData)
│   ├── Services/                    ← FeedingService, DiaperService,
│   │                                  LiveActivityManager, ReminderScheduler,
│   │                                  NotificationDelegate
│   ├── SharedAttributes/            ← FeedingAttributes, AppGroup, NotificationIdentifiers
│   ├── AppIntents/                  ← SwitchBreastIntent, StopFeedingIntent
│   ├── Features/Home/               ← IdleHomeView, ActiveSessionView, BreastPickerSheet, NoteSheet
│   ├── Features/PostFeed/           ← PumpedMlSheet, DiaperSheet
│   ├── Features/History/            ← HistoryView + 4 sub-views + EditSessionSheet
│   ├── Features/Onboarding/         ← OnboardingSheet
│   ├── Features/Settings/           ← SettingsView
│   └── Resources/                   ← Assets, Localizable.strings (cs)
├── KojeniWidget/                    ← Widget Extension
│   ├── KojeniWidgetBundle.swift
│   └── FeedingLiveActivity.swift
└── KojeniTests/                     ← Swift Testing unit testy
```

---

## Instalace na iPhone

### Předpoklady

- iPhone s iOS 26.1+
- Free Apple ID (žádný Apple Developer Program)
- [AltServer](https://altstore.io) na Macu
- [AltStore](https://altstore.io) na iPhonu

### Stažení IPA

Build IPA z source code (viz `Build from source` níže) NEBO si stáhni hotové z [Releases](https://github.com/pz96cz/denicek-kojici-matky/releases).

### Install přes AltStore

1. AirDrop `Kojeni.ipa` na iPhone (uloží se do Files)
2. AltStore → tab **My Apps** → tlačítko `+` → vyber `Kojeni.ipa`
3. AltStore se zeptá na Apple ID — vyplň
4. Po instalaci: **Settings → General → VPN & Device Management → tvůj Apple ID → Trust**
5. Spusť app → onboarding → **Allow** na permission notifikací a Live Activities

### Omezení free Apple ID

- **7denní re-sign** — appka přestane fungovat po 7 dnech, pokud Mac s AltServerem nebude na stejné WiFi alespoň jednou za 7 dní (AltStore notifikuje za 2 dny)
- **3 sideloaded apps najednou** na jednoho Apple ID
- **App Group entitlement nepřežije AltStore re-sign** → Live Activity tlačítka místo silent action otevírají hlavní app (mamka musí odemknout pro Switch / Stop). Spec section 1.3 „bez odemykání" striktně ne, ale data nepadají.
- Pro full silent Live Activity intenty by bylo potřeba **placený Apple Developer Program ($99/rok)** a TestFlight místo AltStore.

---

## Build from source

### Předpoklady

- Mac s Xcode 26+
- Apple ID přihlášený v Xcode (Settings → Accounts)
- Fyzický iPhone připojený USB (jednorázová registrace pro signing — viz [project_signing.md](#))

### Setup

```bash
git clone git@github.com:pz96cz/denicek-kojici-matky.git
cd denicek-kojici-matky
open Kojeni/Kojeni.xcodeproj
```

V Xcode:
- Vyber target **Kojeni** → záložka **Signing & Capabilities** → nastav svůj Personal Team
- Stejné pro target **KojeniWidgetExtension**
- Pro App Group: připoj fyzický iPhone, povol Developer Mode na něm (`Settings → Privacy & Security → Developer Mode`)
- ⌘ B (Build) → ⌘ U (Tests)

### Run na simulátoru

V Xcode top liště vyber simulator iPhone 17 Pro+ (iOS 26.5) → ⌘R.

### Run na fyzickém iPhonu

V Xcode top liště vyber tvůj iPhone → ⌘R. Apple Development cert podepíše app napřímo (bez AltStore re-signu — App Group entitlement zůstane funkční).

### Archive + IPA pro AltStore

```bash
xcodebuild archive \
  -project Kojeni/Kojeni.xcodeproj \
  -scheme Kojeni \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/Kojeni.xcarchive

# package .app into IPA
mkdir -p /tmp/Payload
cp -R /tmp/Kojeni.xcarchive/Products/Applications/Kojeni.app /tmp/Payload/
cd /tmp && zip -r ~/Desktop/Kojeni.ipa Payload
```

Distribute App přes Xcode Organizer NEFUNGUJE — vyžaduje placený Apple Developer Program.

### Testy

```bash
xcodebuild test \
  -project Kojeni/Kojeni.xcodeproj \
  -scheme Kojeni \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO
```

`-parallel-testing-enabled NO` je důležité — iOS 26.5 simulator s parallel Swift Testing trpí náhodnými crashy v Swift stdlib.

70+ unit testů, target coverage ≥ 70% na Models + Services.

---

## Vývojářské poznámky

### Pre-production akcept

- **Žádný cloud, žádný backend** — vše lokálně v SwiftData store
- **Žádný export/import** dat (Apple Health, CSV, PDF) — out of scope
- **Jedna aplikace, jedno miminko** — žádné multi-baby support
- **iPhone only**, žádný iPad layout, žádný landscape
- **Jen čeština** — `cs.lproj/Localizable.strings`

### Architektura

- Žádný singleton (`.shared`) — bránilo by testování a budoucímu rozšíření
- Services jsou `@MainActor final class` s injekcí `ModelContext` přes init
- Views odběrují services in-place přes `@Environment(\.modelContext)`
- LiveActivityManager + ReminderScheduler injectovány přes `@Observable` + `@Environment(Type.self)` typed environment (iOS 17+ pattern)
- App Group bypass pro AltStore — `ModelContainer` používá default sandbox; oba App Intents `openAppWhenRun = true` aby běžely v main app procesu

### Známé limity

- **App Group entitlement nepřežije AltStore re-sign** (řešeno openAppWhenRun)
- **Cross-process SwiftData @Query auto-refresh** chybí — main app fresh-fetch on `scenePhase = .active`
- **Pickup PumpedMlSheet** přes `UserDefaults.standard` flag (ne App Group — viz výše)
- **8h Live Activity limit** — iOS automaticky ukončí, banner v ActiveSessionView upozorní

### Plány implementace (Solution Design)

Projekt byl postavený podle 6 plánů uložených v `docs/superpowers/plans/`:

1. **Plan 1: Foundation** — Xcode project, SwiftData modely, TabView shell, OnboardingSheet
2. **Plan 2: Feeding core** — FeedingService, DiaperService, HomeView idle/active, BreastPickerSheet, PumpedMlSheet, DiaperSheet
3. **Plan 3: Live Activity** — Widget Extension, FeedingAttributes, LiveActivityManager, App Intents, App Group setup
4. **Plan 4: Reminders** — ReminderScheduler, NotificationDelegate, permission flow, SettingsView, banner pokud denied
5. **Plan 5: Historie** — segmented picker, Timeline/Chart/List/Statistics views, EditSessionSheet
6. **Plan 6: Polish** — error banners, 12h forgotten session dialog, orphan PumpedMlSheet pickup, a11y labels *(neimplementováno, plan pouze napsaný)*

Tag `v0.X.0` na main reprezentuje dokončený stav daného plánu.

---

## Licence

MIT — viz [LICENSE](LICENSE) (TODO: přidat soubor).

Tato appka je osobní projekt a není distribuovaná v App Store. Volně použij kód, ale prosím respektuj že je psaný pro konkrétní use-case (jedna mamka, jedno miminko) a může postrádat edge cases co potkáš v širším použití.

---

## Soukromí

- **Žádná data neopouštějí telefon.** SwiftData store je local-only v App Group sandboxu.
- **Žádná telemetry, žádný crash reporting.** Pokud něco selže, vidíš to v Xcode console při dalším AltStore connect.
- **Notifikace jsou lokální** — žádné push tokeny, žádný server.

---

🤱 Made with care for one specific mom.
