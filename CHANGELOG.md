# Changelog

## [0.1.0] — Plan 1: Foundation — 2026-06-06

- Xcode 26 projekt (iOS 26.5+, portrait-only iPhone, Swift 6).
- SwiftData modely: FeedingSession, BreastChange, DiaperEvent, AppSettings.
- Production ModelContainer v @main App.
- TabView shell: Domů / Historie / Nastavení (placeholdery).
- OnboardingSheet při prvním spuštění s nastavením intervalu reminderu (30–360 min, default 180).
- Localizable.strings (cs) base + development region nastaven na Czech.
- Swift Testing unit testy modelů + segments helper + AppSettings clamping (25 testů, všechny zelené).
