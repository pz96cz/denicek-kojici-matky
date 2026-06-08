# CLAUDE.md

Project context for Claude Code working on **Deníček kojicí matky** (iOS breastfeeding diary app).

## Quick facts

- **What:** iOS app pro maminku po porodu — kojení timer, plenky, poznámky, Live Activity, lokální notifikace
- **For:** Konkrétní jedna mamka (osobní projekt), nedistribuováno v App Store
- **Distribution:** AltStore + free Apple ID, **bez** placeného Apple Developer Program
- **GitHub:** https://github.com/pz96cz/denicek-kojici-matky
- **Bundle ID:** `cz.zapletal.Kojeni` · **Display name:** `Deníček kojicí matky`
- **MinOS:** iOS 26.1+ · **Xcode:** 26+ · **Swift:** 6
- **Jazyk:** Pouze čeština v UI (`cs.lproj/Localizable.strings`)

## Tech stack

- SwiftUI + SwiftData (`@Model`, `@Query`, `ModelContainer`)
- ActivityKit + WidgetKit (Live Activity)
- App Intents (Lock Screen buttons — see workaround below)
- UserNotifications (lokální notifikace + akce)
- Swift Charts (týdenní graf)
- **Swift Testing** (`@Suite`, `@Test`, `#expect`) — ne XCTest
- Žádné external dependency

## Project layout

```
Kojeni/Kojeni.xcodeproj              ← otevři tímto
Kojeni/Kojeni/                       ← main app target (synced folder)
  ├ KojeniApp.swift                  ← @main, ModelContainer
  ├ App/RootView.swift               ← TabView shell
  ├ Models/                          ← @Model entity (FeedingSession, BreastChange, DiaperEvent, AppSettings)
  ├ Services/                        ← FeedingService, DiaperService, LiveActivityManager, ReminderScheduler, NotificationDelegate
  ├ SharedAttributes/                ← FeedingAttributes, AppGroup, NotificationIdentifiers
  ├ AppIntents/                      ← SwitchBreastIntent, StopFeedingIntent (oba openAppWhenRun=true — viz níže)
  └ Features/{Home,PostFeed,History,Onboarding,Settings}/
Kojeni/KojeniWidget/                 ← widget extension target (synced folder)
  ├ KojeniWidgetBundle.swift         ← @main on WidgetBundle
  ├ FeedingLiveActivity.swift        ← Lock Screen + Dynamic Island
  └ Info.plist                       ← manuální, MUSÍ obsahovat EXAppExtensionAttributes
Kojeni/KojeniTests/                  ← Swift Testing unit testy (70+)
docs/superpowers/plans/              ← 6 implementačních plánů
```

## Critical commands

Vždy používej tyto absolutní cesty + cached UDIDs (viz memory `project_simulators`):

```bash
# Simulator UDIDs (iOS 26.5, oba booted defaultně)
SIM_PRO=E7D54495-1FBF-4E65-B7E4-F55D51806898       # iPhone 17 Pro (default)
SIM_MAX=8642F9E0-4452-421F-AFA1-DD31D947F658       # iPhone 17 Pro Max
SIMCTL=/Applications/Xcode.app/Contents/Developer/usr/bin/simctl
XCODEBUILD="DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"

# Build (debug)
$XCODEBUILD build -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination "platform=iOS Simulator,id=$SIM_PRO" \
  -derivedDataPath /tmp/kojeni-quick -quiet

# Tests — MUSÍ být -parallel-testing-enabled NO (Swift Testing iOS 26.5 bug)
$XCODEBUILD test -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -destination "platform=iOS Simulator,id=$SIM_PRO" \
  -parallel-testing-enabled NO

# Install + launch (rychlá iterace)
$SIMCTL terminate $SIM_PRO cz.zapletal.Kojeni 2>/dev/null
$SIMCTL install $SIM_PRO /tmp/kojeni-quick/Build/Products/Debug-iphonesimulator/Kojeni.app
$SIMCTL launch $SIM_PRO cz.zapletal.Kojeni
$SIMCTL io $SIM_PRO screenshot /tmp/kojeni-X.png   # → Read tool zobrazí PNG

# Archive + IPA pro AltStore install na iPhone
$XCODEBUILD archive -project Kojeni/Kojeni.xcodeproj -scheme Kojeni \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/Kojeni.xcarchive -quiet
mkdir -p /tmp/Payload && cp -R /tmp/Kojeni.xcarchive/Products/Applications/Kojeni.app /tmp/Payload/
cd /tmp && zip -r ~/Desktop/Kojeni.ipa Payload && rm -rf /tmp/Payload
# → user pak AirDropuje ~/Desktop/Kojeni.ipa do iPhonu a installne v AltStore
```

**Schema migrace:** Při přidání `@Model` field (nullable additive je OK) je nutné `$SIMCTL erase $SIM_PRO` pro fresh store, jinak SwiftData crash.

## Klíčová workaroundy a pitfally (důležité!)

**Před debug Live Activity** přečti `memory/project_xcode26_widget_pitfalls.md` — 5 silent-fail konfigů (NSSupportsLiveActivities, EXAppExtensionAttributes, membershipExceptions, timer range, ne NSExtensionPrincipalClass).

**App Group bypass** (`memory/project_altstore_workaround.md`):
- `ModelContainer` v main app + intents: bez `groupContainer:` (default sandbox)
- `UserDefaults.standard`, ne `UserDefaults(suiteName:)`
- Oba App Intents: `AppIntent` s `static var openAppWhenRun: Bool = true` (ne `LiveActivityIntent`)
- Důvod: AltStore re-sign strippuje App Group entitlement

**Při Live Activity timer:** `start...start.addingTimeInterval(8 * 3600)`, NIKDY `Date.distantFuture` (formátuje "1:--").

## Coding conventions

- **Žádné singletons** (`.shared`) — bránilo by testování. Services jsou `@MainActor final class` injectované přes init.
- **DI patterns:**
  - `ModelContext` via `@Environment(\.modelContext)`
  - `LiveActivityManager`, `ReminderScheduler` via `@Observable` + `@Environment(Type.self)` (iOS 17+ typed environment)
- **Žádné komentáře** popisující CO kód dělá. Komentář jedině když vysvětluje proč/edge case/workaround (např. `// Date.distantFuture rozhází timerInterval format, použij 8h max LA lifetime`).
- **Czech strings inline** v `Text("...")` jsou OK pro tento projekt (jednojazyčný). Není potřeba i18n přes `LocalizedStringResource`.
- **SwiftData saves:** `try? modelContext.save()` po každé mutaci. Žádný debounce.
- **Test framework:** Swift Testing only. `@Suite @MainActor struct FooTests { @Test func bar_does_x() { #expect(...) } }`. Test naming: `subject_action_outcome` (snake-style v rámci func name OK).

## Komunikace s uživatelem

`memory/feedback_terminal_workflow.md` má detaily, summary:
- **Čeština neformální** (`ty`), krátké, bez diakritiky uživatel taky píše krátce
- **Terminal-driven loop** preferovaný — neklikat skrz Xcode UI
- **Po každé změně:** commit + 1-2 věty co se změnilo + commit hash. Žádné dlouhé recapy.
- **Screenshot** po install pro vizuální ověření (`simctl io screenshot`)
- **Plan/spec content** je v `docs/superpowers/plans/` + `docs/superpowers/specs/` — pokud potřebuješ kontext k feature, hledej tam

## Co NEdělat

- ❌ **Distribute App přes Xcode Organizer** — vyžaduje paid Developer Program ($99/rok). Použij manuální `zip Payload/` flow.
- ❌ **Singleton `.shared`** — žádný service tak nestaví.
- ❌ **External dependency** — projekt je čistý Apple stack. Žádné SPM dependencies.
- ❌ **App Group v ModelContainer** — viz workaround výše.
- ❌ **`LiveActivityIntent`** — viz workaround.
- ❌ **Parallel Swift Testing na iOS 26.5** — viz test flags.
- ❌ **Multi-baby support, iPad layout, landscape, Apple Health, CSV export** — explicitně out of scope per spec.

## Plan execution

Projekt byl postavený podle 6 plánů (`docs/superpowers/plans/`). Pokud user řekne "pojďme na plan N" nebo "task M z planu N", použij **subagent-driven-development** workflow (implementer → spec reviewer → code quality reviewer per task). Plan 1–5 jsou hotové (tags `v0.1.0` až `v0.5.0`). Plan 6 (Polish) je napsaný ale neimplementovaný.

## Memory files

V `~/.claude/projects/-Users-pz-Documents-develop-kojeni-app/memory/` jsou detailnější notes:
- `project_signing.md` — Personal Team + App Group prerekvizity
- `project_targets.md` — Xcode target naming reality
- `project_altstore_workaround.md` — App Group bypass detaily
- `project_xcode26_widget_pitfalls.md` — Live Activity debugging guide
- `project_test_flags.md` — test runner flags
- `project_simulators.md` — cached sim UDIDs
- `feedback_terminal_workflow.md` — komunikační styl
- `reference_github.md` — repo + branding
