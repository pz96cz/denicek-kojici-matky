# Changelog

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
