# Changelog

## [0.5.0] — Plan 5: Historie — 2026-06-07

- `HistoryView` se segmented pickerem 4 sub-views.
- `TodayTimelineView` — 24h vertikální timeline dnešních eventů, sezení jako modré boxy, plenky jako tečky.
- `WeeklyChartView` — Swift Charts stacked bar (7 dní), přepínač metriky Délka kojení / Počet plenek.
- `SessionListView` — chronologický scroll list grupovaný po dnech, heterogeneous (sezení + plenky dohromady).
- `StatisticsView` — 6 karet (sezení/den, ⌀ délka, ⌀ interval, plenek/den, suma ml/týden, sezení celkem).
- `EditSessionSheet` — Form edit startedAt/endedAt/initialBreast/pumpedMl, smazání s confirmation.
- `HistoryStatistics` value struct + `.compute(over:)` factory (8 unit testů).
- 8 nových Swift Testing testů. Po mergi s Plan 4 celkem **69**.

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
- Vyvinuto paralelně s Plan 5 (Historie) ve dvou git worktrees + 2 simulátorech.

## [0.3.0] — Plan 3: Live Activity — 2026-06-07

- Widget Extension target `KojeniWidgetExtension` (folder `Kojeni/KojeniWidget/`).
- `FeedingAttributes` (ActivityKit) sdíleno mezi main app a widget targety přes bulk target membership (Build Phases > Compile Sources).
- `LiveActivityManager` — `@MainActor @Observable` wrapper kolem `Activity<FeedingAttributes>` API. request/update/end + re-attach po restartu.
- `SwitchBreastIntent` jako `LiveActivityIntent` — běží v widget procesu, žádné odemykání. Otevře sdílený SwiftData container přes App Group, volá `FeedingService.switchBreast()`, aktualizuje LA.
- `StopFeedingIntent` jako `AppIntent openAppWhenRun = true` — otevře main app, předá routing signál (UserDefaults v App Group suite) pro otevření `PumpedMlSheet`.
- App Group `group.cz.zapletal.kojeni` centralizovaný v `AppGroup.identifier` konstantě (Kojeni + KojeniWidgetExtension entitlements).
- Re-attach LA + pickup PumpedMlSheet routing přes `scenePhase = .active` v `RootView`. Explicit `FetchDescriptor` (ne stale `@Query`) na cross-process write z widget procesu.
- Banner v `ActiveSessionView` pro sezení > 8h (LA expired).
- Swift 6 nonisolated fixes na pure value types (AppGroup, FeedingAttributes).
- 4 nové Swift Testing testy (3 FeedingAttributes Codable + 1 LiveActivityManager rev start guard). Celkem 49.

## [0.2.0] — Plan 2: Feeding core — 2026-06-06

- `FeedingService` se startSession (s invariantem žádných 2 aktivních), switchBreast (alternuje), endSession (idempotentní).
- `DiaperService` s logPee a logPoo (s konzistencí).
- HomeView se přepíná mezi `IdleHomeView` (Kojit + Plenky) a `ActiveSessionView` (timer + Stop + Přehodit prso) na základě `@Query` aktivních sezení.
- `BreastPickerSheet` po Kojit, default zvýrazněno opačné prso než minulé sezení.
- `PumpedMlSheet` po Stop pro záznam ml (default 0, Stepper krok 5, rozsah 0–300).
- `DiaperSheet` po Kakání pro výběr konzistence (Řídké / Normální / Tvrdé).
- 17 nových Swift Testing testů pro služby (42 celkem, všechny zelené).
- Plán Task 8 opraven o ternary-buttonStyle typecheck bug (`@ViewBuilder` if/else split).

## [0.1.0] — Plan 1: Foundation — 2026-06-06

- Xcode 26 projekt (iOS 26.5+, portrait-only iPhone, Swift 6).
- SwiftData modely: FeedingSession, BreastChange, DiaperEvent, AppSettings.
- Production ModelContainer v @main App.
- TabView shell: Domů / Historie / Nastavení (placeholdery).
- OnboardingSheet při prvním spuštění s nastavením intervalu reminderu (30–360 min, default 180).
- Localizable.strings (cs) base + development region nastaven na Czech.
- Swift Testing unit testy modelů + segments helper + AppSettings clamping (25 testů, všechny zelené).
