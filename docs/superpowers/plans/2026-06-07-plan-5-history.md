# Kojení — Plan 5: Historie

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** History tab se 4 podpohledy přes segmented picker (spec sekce 4): **Dnes** (vertikální timeline 24h), **Týden** (Swift Charts stacked bar), **Seznam** (chronologický scroll po dnech), **Statistiky** (karty s průměry a součty). Sezení lze editovat přes `EditSessionSheet` — opravit pumpedMl, časy, smazat.

**Architecture:** Čistě SwiftUI + SwiftData reads (žádný nový service). Každý sub-view má vlastní `@Query` s vlastním predicate/sort. Statistiky a derived data (segments, totals) jsou computed properties / extensions na modelech, ne separate service. Swift Charts pro graf. Žádný Xcode UI step, žádné entitlements, žádný target membership — vše v Kojeni target.

**Tech Stack:** Swift 6+, Xcode 26+, iOS 26.5+, SwiftUI, SwiftData, **Swift Charts**, Swift Testing. Žádné externí dependency.

> Plan navazuje na Plan 1-3 (Plan 4 paralelní — žádný overlap). Předpokládá `FeedingSession`, `DiaperEvent`, `BreastChange`, `FeedingSession.segments()` (Plan 1 Task 4 helper), `AppSettings`.

---

## File Structure (po dokončení Plan 5)

```
Kojeni/Kojeni/
├── Models/
│   └── HistoryStatistics.swift              ← NEW (struct + factory funkce pro statistiky)
└── Features/
    └── History/
        ├── HistoryView.swift                ← REWRITE: segmented picker + 4 sub-views
        ├── TodayTimelineView.swift          ← NEW
        ├── WeeklyChartView.swift            ← NEW
        ├── SessionListView.swift            ← NEW
        ├── StatisticsView.swift             ← NEW
        └── EditSessionSheet.swift           ← NEW

Kojeni/KojeniTests/
├── Models/
│   └── HistoryStatisticsTests.swift         ← NEW (8 testů průměrů a součtů)
└── Features/
    └── (UI views se netestují — jen statistics helper)
```

**Vědomě NEpatří do Plan 5:**
- Akce ze statistik (např. „smaž starší než X" bulk delete) — Plan 6 polish.
- Plot/widget na home tab — Plan 6.
- Histogram intervalů mezi kojeními — Plan 6.
- Export do PDF/CSV — out of scope úplně (spec sekce 1.2 explicit out of scope: žádný Apple Health export).

---

## Task 1: `HistoryStatistics` struct + 4 helper funkce

**Files:**
- Create: `Kojeni/Kojeni/Models/HistoryStatistics.swift`
- Create: `Kojeni/KojeniTests/Models/HistoryStatisticsTests.swift`

**Cíl:** Pure data struct `HistoryStatistics` se 6 metrikami pro `StatisticsView`. Factory `compute(sessions:diapers:over:)` agreguje data za posledních N dní (default 7).

- [ ] **Step 1: Napiš failing testy**

`Kojeni/KojeniTests/Models/HistoryStatisticsTests.swift`:

```swift
import Testing
import Foundation
@testable import Kojeni

@Suite @MainActor
struct HistoryStatisticsTests {

    /// Helper — vyrobit sezení o známé délce skončené v určitý čas.
    private func makeSession(startedAt: Date, durationMinutes: Int,
                             breast: Breast = .left, pumpedMl: Int? = nil) -> FeedingSession {
        let s = FeedingSession(startedAt: startedAt, initialBreast: breast)
        s.endedAt = startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        s.pumpedMl = pumpedMl
        return s
    }

    @Test func empty_data_returns_zero_stats() {
        let stats = HistoryStatistics.compute(sessions: [], diapers: [], over: 7)
        #expect(stats.avgSessionsPerDay == 0)
        #expect(stats.avgSessionDurationMinutes == 0)
        #expect(stats.avgIntervalBetweenSessionsMinutes == 0)
        #expect(stats.avgDiapersPerDay == 0)
        #expect(stats.totalPumpedMl == 0)
        #expect(stats.sessionCount == 0)
    }

    @Test func single_session_no_interval() {
        let now = Date.now
        let s = makeSession(startedAt: now.addingTimeInterval(-3600), durationMinutes: 30)
        let stats = HistoryStatistics.compute(sessions: [s], diapers: [], over: 7)
        #expect(stats.sessionCount == 1)
        #expect(stats.avgSessionDurationMinutes == 30)
        // Single sezení → žádný interval (potřebuje 2+ sezení).
        #expect(stats.avgIntervalBetweenSessionsMinutes == 0)
    }

    @Test func two_sessions_interval_calculated() {
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        let s1 = makeSession(startedAt: t0, durationMinutes: 20)
        // Druhé sezení startuje 3h po konci prvního.
        let s2 = makeSession(startedAt: t0.addingTimeInterval(20 * 60 + 3 * 3600),
                              durationMinutes: 25)
        let stats = HistoryStatistics.compute(sessions: [s1, s2], diapers: [], over: 7)
        #expect(stats.sessionCount == 2)
        #expect(stats.avgIntervalBetweenSessionsMinutes == 180)   // 3h = 180 min
    }

    @Test func avgSessionsPerDay_uses_window() {
        // 14 sezení za 7 dní → průměr 2/den.
        let now = Date.now
        let sessions = (0..<14).map { i in
            makeSession(startedAt: now.addingTimeInterval(-Double(i * 12 * 3600)),
                       durationMinutes: 20)
        }
        let stats = HistoryStatistics.compute(sessions: sessions, diapers: [], over: 7)
        #expect(stats.avgSessionsPerDay == 2.0)
    }

    @Test func totalPumpedMl_sums_only_non_nil() {
        let now = Date.now
        let s1 = makeSession(startedAt: now, durationMinutes: 10, pumpedMl: 50)
        let s2 = makeSession(startedAt: now, durationMinutes: 10, pumpedMl: nil)
        let s3 = makeSession(startedAt: now, durationMinutes: 10, pumpedMl: 30)
        let stats = HistoryStatistics.compute(sessions: [s1, s2, s3], diapers: [], over: 7)
        #expect(stats.totalPumpedMl == 80)
    }

    @Test func avgDiapersPerDay_simple() {
        let now = Date.now
        let diapers = (0..<14).map { i in
            DiaperEvent(at: now.addingTimeInterval(-Double(i * 12 * 3600)), kind: .pee)
        }
        let stats = HistoryStatistics.compute(sessions: [], diapers: diapers, over: 7)
        #expect(stats.avgDiapersPerDay == 2.0)
    }

    @Test func compute_filters_to_window() {
        let now = Date.now
        let recent = makeSession(startedAt: now.addingTimeInterval(-3600), durationMinutes: 20)
        let old = makeSession(startedAt: now.addingTimeInterval(-30 * 24 * 3600),
                              durationMinutes: 20)
        // Bereme jen recent za posledních 7 dní.
        let stats = HistoryStatistics.compute(sessions: [recent, old], diapers: [], over: 7)
        #expect(stats.sessionCount == 1)
    }

    @Test func active_sessions_excluded_from_duration_avg() {
        let now = Date.now
        let ended = makeSession(startedAt: now.addingTimeInterval(-3600), durationMinutes: 30)
        let active = FeedingSession(startedAt: now.addingTimeInterval(-600), initialBreast: .left)
        // active.endedAt zůstává nil

        let stats = HistoryStatistics.compute(sessions: [ended, active], diapers: [], over: 7)
        #expect(stats.sessionCount == 1)   // active session se nepočítá
        #expect(stats.avgSessionDurationMinutes == 30)
    }
}
```

- [ ] **Step 2: Pusť testy — selžou**

Expected: `Cannot find 'HistoryStatistics' in scope`.

- [ ] **Step 3: Implementuj `HistoryStatistics`**

`Kojeni/Kojeni/Models/HistoryStatistics.swift`:

```swift
import Foundation

/// Agregované statistiky pro `StatisticsView`.
/// Pure value type — žádné closure, žádné services. Spočítá `compute(...)`.
struct HistoryStatistics: Equatable {

    /// Průměrný počet kojicích sezení za den (přes okno).
    var avgSessionsPerDay: Double
    /// Průměrná délka jednoho sezení v minutách.
    var avgSessionDurationMinutes: Double
    /// Průměrný interval mezi sezeními v minutách (mezi konci a začátky).
    var avgIntervalBetweenSessionsMinutes: Double
    /// Průměrný počet plenkových událostí za den.
    var avgDiapersPerDay: Double
    /// Suma odstříkaných ml v okně (jen sezení s pumpedMl != nil).
    var totalPumpedMl: Int
    /// Počet ukončených sezení v okně.
    var sessionCount: Int

    static let zero = HistoryStatistics(
        avgSessionsPerDay: 0,
        avgSessionDurationMinutes: 0,
        avgIntervalBetweenSessionsMinutes: 0,
        avgDiapersPerDay: 0,
        totalPumpedMl: 0,
        sessionCount: 0
    )

    /// Spočítá statistiky z poskytnutých dat za posledních `over` dní.
    /// Pouze ukončená sezení (endedAt != nil) se počítají do duration/count.
    static func compute(sessions: [FeedingSession],
                        diapers: [DiaperEvent],
                        over days: Int) -> HistoryStatistics {
        let now = Date.now
        let windowStart = now.addingTimeInterval(-Double(days) * 24 * 3600)

        // Filter na okno + jen ukončená.
        let recentEnded = sessions.filter { session in
            guard let endedAt = session.endedAt else { return false }
            return endedAt >= windowStart
        }
        let recentDiapers = diapers.filter { $0.at >= windowStart }

        guard !recentEnded.isEmpty || !recentDiapers.isEmpty else {
            return .zero
        }

        let count = recentEnded.count
        let totalDuration = recentEnded.reduce(0.0) { $0 + $1.duration }
        let avgDuration = count > 0 ? totalDuration / Double(count) / 60.0 : 0

        // Interval = (session[i+1].startedAt - session[i].endedAt) průměrně.
        let sortedAsc = recentEnded
            .sorted { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
        var intervalsTotal: Double = 0
        var intervalCount = 0
        for i in 0..<(sortedAsc.count - 1) where sortedAsc.count > 1 {
            guard let endedAt = sortedAsc[i].endedAt else { continue }
            let gap = sortedAsc[i+1].startedAt.timeIntervalSince(endedAt)
            if gap > 0 {
                intervalsTotal += gap
                intervalCount += 1
            }
        }
        let avgInterval = intervalCount > 0
            ? intervalsTotal / Double(intervalCount) / 60.0 : 0

        let totalPumped = recentEnded.compactMap { $0.pumpedMl }.reduce(0, +)

        let denominator = max(Double(days), 1)
        let avgSessions = Double(count) / denominator
        let avgDiapers = Double(recentDiapers.count) / denominator

        return HistoryStatistics(
            avgSessionsPerDay: avgSessions,
            avgSessionDurationMinutes: avgDuration,
            avgIntervalBetweenSessionsMinutes: avgInterval,
            avgDiapersPerDay: avgDiapers,
            totalPumpedMl: totalPumped,
            sessionCount: count
        )
    }
}
```

- [ ] **Step 4: Pusť testy — projdou**

Expected: 57 passed (49 + 8 nové HistoryStatistics testy).

- [ ] **Step 5: Commit**

```bash
git add Kojeni/Kojeni/Models/HistoryStatistics.swift \
        Kojeni/KojeniTests/Models/HistoryStatisticsTests.swift
git commit -m "feat(stats): HistoryStatistics struct + compute() factory"
```

---

## Task 2: Restructure `HistoryView` se segmented picker + 4 placeholdery

**Files:**
- Modify: `Kojeni/Kojeni/Features/History/HistoryView.swift`
- Create: `Kojeni/Kojeni/Features/History/TodayTimelineView.swift` (placeholder)
- Create: `Kojeni/Kojeni/Features/History/WeeklyChartView.swift` (placeholder)
- Create: `Kojeni/Kojeni/Features/History/SessionListView.swift` (placeholder)
- Create: `Kojeni/Kojeni/Features/History/StatisticsView.swift` (placeholder)

**Cíl:** Kostra navigace. HistoryView má Picker s 4 segmenty, podle výběru ukáže jeden z 4 sub-views. Placeholdery zatím — naplníme Tasks 3-6.

- [ ] **Step 1: Vytvoř 4 placeholder views**

`Kojeni/Kojeni/Features/History/TodayTimelineView.swift`:

```swift
import SwiftUI

struct TodayTimelineView: View {
    var body: some View {
        Text("Dnes — timeline (placeholder)")
    }
}
```

`Kojeni/Kojeni/Features/History/WeeklyChartView.swift`:

```swift
import SwiftUI

struct WeeklyChartView: View {
    var body: some View {
        Text("Týden — graf (placeholder)")
    }
}
```

`Kojeni/Kojeni/Features/History/SessionListView.swift`:

```swift
import SwiftUI

struct SessionListView: View {
    var body: some View {
        Text("Seznam (placeholder)")
    }
}
```

`Kojeni/Kojeni/Features/History/StatisticsView.swift`:

```swift
import SwiftUI

struct StatisticsView: View {
    var body: some View {
        Text("Statistiky (placeholder)")
    }
}
```

- [ ] **Step 2: Přepiš `HistoryView`**

```swift
import SwiftUI

struct HistoryView: View {

    enum Segment: String, CaseIterable, Identifiable {
        case today      = "Dnes"
        case week       = "Týden"
        case list       = "Seznam"
        case statistics = "Statistiky"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .today

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Pohled", selection: $segment) {
                    ForEach(Segment.allCases) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                Group {
                    switch segment {
                    case .today:      TodayTimelineView()
                    case .week:       WeeklyChartView()
                    case .list:       SessionListView()
                    case .statistics: StatisticsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Historie")
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [FeedingSession.self, DiaperEvent.self], inMemory: true)
}
```

- [ ] **Step 3: Build + tests**

Expected: 57 passed (žádný regress).

- [ ] **Step 4: Commit**

```bash
git add Kojeni/Kojeni/Features/History
git commit -m "feat(history): segmented picker + 4 placeholder sub-views"
```

---

## Task 3: `StatisticsView` — implement using HistoryStatistics

**Files:**
- Modify: `Kojeni/Kojeni/Features/History/StatisticsView.swift`

**Cíl:** 6 karet (LazyVGrid 2 sloupce) zobrazujících metriky z `HistoryStatistics`. Spočítají se přes `@Query` načtená data + `HistoryStatistics.compute(over: 7)`.

- [ ] **Step 1: Přepiš `StatisticsView`**

```swift
import SwiftUI
import SwiftData

struct StatisticsView: View {

    @Query private var sessions: [FeedingSession]
    @Query private var diapers: [DiaperEvent]

    private var stats: HistoryStatistics {
        HistoryStatistics.compute(sessions: sessions, diapers: diapers, over: 7)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Za posledních 7 dní")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    statCard(title: "Sezení/den",
                             value: formatted(stats.avgSessionsPerDay, decimals: 1))
                    statCard(title: "⌀ délka",
                             value: "\(Int(stats.avgSessionDurationMinutes.rounded())) min")
                    statCard(title: "⌀ interval",
                             value: formattedInterval(Int(stats.avgIntervalBetweenSessionsMinutes.rounded())))
                    statCard(title: "Plenek/den",
                             value: formatted(stats.avgDiapersPerDay, decimals: 1))
                    statCard(title: "Σ ml týden",
                             value: "\(stats.totalPumpedMl) ml")
                    statCard(title: "Sezení celkem",
                             value: "\(stats.sessionCount)")
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatted(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }

    private func formattedInterval(_ minutes: Int) -> String {
        if minutes == 0 { return "—" }
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) min"
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [FeedingSession.self, DiaperEvent.self], inMemory: true)
}
```

- [ ] **Step 2: Build + tests**

Expected: 57 passed.

- [ ] **Step 3: Commit**

```bash
git add Kojeni/Kojeni/Features/History/StatisticsView.swift
git commit -m "feat(history): StatisticsView with 6 metric cards"
```

---

## Task 4: `SessionListView` — chronological list with day sections

**Files:**
- Modify: `Kojeni/Kojeni/Features/History/SessionListView.swift`
- Create: `Kojeni/Kojeni/Features/History/EditSessionSheet.swift` (placeholder — Task 6 dořeší)

**Cíl:** Scroll list sezení a plenek dohromady, grupované po dnech. Každý řádek: čas + ikona + délka/objem. Tap → EditSessionSheet (Task 6).

> Plenky a sezení dohromady na jedné timeline — uživatelka chce vidět context.

- [ ] **Step 1: Vytvoř `EditSessionSheet` placeholder**

```swift
import SwiftUI

struct EditSessionSheet: View {
    let session: FeedingSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Text("Edit session (placeholder)")
        Button("Zavřít") { dismiss() }
    }
}
```

- [ ] **Step 2: Přepiš `SessionListView`**

```swift
import SwiftUI
import SwiftData

struct SessionListView: View {

    @Query(sort: \FeedingSession.startedAt, order: .reverse)
    private var sessions: [FeedingSession]

    @Query(sort: \DiaperEvent.at, order: .reverse)
    private var diapers: [DiaperEvent]

    @State private var editingSession: FeedingSession?

    /// Heterogeneous timeline items unified pro grupování.
    enum TimelineItem: Identifiable {
        case feeding(FeedingSession)
        case diaper(DiaperEvent)

        var id: String {
            switch self {
            case .feeding(let s): return "feeding-\(s.id)"
            case .diaper(let d):  return "diaper-\(d.id)"
            }
        }

        var sortDate: Date {
            switch self {
            case .feeding(let s): return s.startedAt
            case .diaper(let d):  return d.at
            }
        }
    }

    private var groupedByDay: [(Date, [TimelineItem])] {
        let all: [TimelineItem] = sessions.map { .feeding($0) } + diapers.map { .diaper($0) }
        let sorted = all.sorted { $0.sortDate > $1.sortDate }
        let grouped = Dictionary(grouping: sorted) { item in
            Calendar.current.startOfDay(for: item.sortDate)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        List {
            ForEach(groupedByDay, id: \.0) { day, items in
                Section(header: Text(formattedDay(day))) {
                    ForEach(items) { item in
                        row(for: item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editingSession) { session in
            EditSessionSheet(session: session)
        }
    }

    @ViewBuilder
    private func row(for item: TimelineItem) -> some View {
        switch item {
        case .feeding(let session):
            Button(action: { editingSession = session }) {
                HStack {
                    Image(systemName: "🤱" == "🤱" ? "person.fill" : "")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(formattedTime(session.startedAt))
                            .font(.subheadline.bold())
                        HStack(spacing: 8) {
                            Text(durationLabel(for: session))
                                .font(.caption.monospacedDigit())
                            if let ml = session.pumpedMl, ml > 0 {
                                Text("• \(ml) ml")
                                    .font(.caption)
                            }
                            Text("• \(label(for: session.currentBreast))")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

        case .diaper(let diaper):
            HStack {
                Image(systemName: diaper.kind == .pee ? "drop.fill" : "circle.fill")
                    .foregroundStyle(diaper.kind == .pee ? .blue : .brown)
                VStack(alignment: .leading) {
                    Text(formattedTime(diaper.at))
                        .font(.subheadline.bold())
                    Text(diaperLabel(for: diaper))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func formattedDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.dateFormat = "EEEE d. M."
        let s = formatter.string(from: date)
        if Calendar.current.isDateInToday(date) { return "Dnes — \(s)" }
        if Calendar.current.isDateInYesterday(date) { return "Včera — \(s)" }
        return s.capitalized
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func durationLabel(for session: FeedingSession) -> String {
        if session.isActive { return "běží…" }
        let mins = Int(session.duration / 60)
        return "\(mins) min"
    }

    private func label(for breast: Breast) -> String {
        switch breast {
        case .left:  return "L"
        case .right: return "P"
        }
    }

    private func diaperLabel(for diaper: DiaperEvent) -> String {
        switch diaper.kind {
        case .pee: return "Čůrání"
        case .poo:
            switch diaper.consistency {
            case .loose:  return "Kakání — řídké"
            case .normal: return "Kakání — normální"
            case .hard:   return "Kakání — tvrdé"
            case .none:   return "Kakání"
            }
        }
    }
}

#Preview {
    SessionListView()
        .modelContainer(for: [FeedingSession.self, DiaperEvent.self, BreastChange.self], inMemory: true)
}
```

- [ ] **Step 3: Build + tests**

Expected: 57 passed.

- [ ] **Step 4: Commit**

```bash
git add Kojeni/Kojeni/Features/History/SessionListView.swift \
        Kojeni/Kojeni/Features/History/EditSessionSheet.swift
git commit -m "feat(history): SessionListView with day-grouped feeding+diaper timeline"
```

---

## Task 5: `TodayTimelineView` — 24h vertical timeline

**Files:**
- Modify: `Kojeni/Kojeni/Features/History/TodayTimelineView.swift`

**Cíl:** Vertikální 24h timeline dnešního dne. Osa Y = hodiny 00–24, na ní eventy jako barevné značky. Tap → EditSessionSheet.

> Simple ScrollView s ZStack — hodinové dělící čáry + eventy umístěné absolutně podle času. Žádný custom Canvas, žádný GeometryReader gymnastics, jen poctivá VStack po hodinách.

- [ ] **Step 1: Přepiš `TodayTimelineView`**

```swift
import SwiftUI
import SwiftData

struct TodayTimelineView: View {

    @Query private var allSessions: [FeedingSession]
    @Query private var allDiapers: [DiaperEvent]
    @State private var editingSession: FeedingSession?

    private var todayStart: Date { Calendar.current.startOfDay(for: .now) }
    private var todayEnd: Date { todayStart.addingTimeInterval(24 * 3600) }

    private var todaySessions: [FeedingSession] {
        allSessions.filter { session in
            session.startedAt >= todayStart && session.startedAt < todayEnd
        }
    }

    private var todayDiapers: [DiaperEvent] {
        allDiapers.filter { $0.at >= todayStart && $0.at < todayEnd }
    }

    /// Výška jedné hodiny v px.
    private let hourHeight: CGFloat = 60

    var body: some View {
        if todaySessions.isEmpty && todayDiapers.isEmpty {
            ContentUnavailableView(
                "Zatím žádné události dnes",
                systemImage: "clock",
                description: Text("Sezení a plenky se objeví tady jak je natrackuješ.")
            )
        } else {
            ScrollView {
                ZStack(alignment: .topLeading) {
                    hourLinesAndLabels
                    sessionMarkers
                    diaperMarkers
                }
                .frame(height: hourHeight * 24)
                .padding(.vertical)
            }
            .sheet(item: $editingSession) { session in
                EditSessionSheet(session: session)
            }
        }
    }

    private var hourLinesAndLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<24) { hour in
                HStack(alignment: .top, spacing: 4) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .frame(height: 0.5)
                        .padding(.top, 6)
                    Spacer()
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
    }

    private var sessionMarkers: some View {
        ForEach(todaySessions, id: \.id) { session in
            sessionBar(session)
        }
    }

    private func sessionBar(_ session: FeedingSession) -> some View {
        let start = session.startedAt
        let end = session.endedAt ?? .now
        let yStart = yOffset(for: start)
        let height = max(yOffset(for: end) - yStart, 4)
        return Button(action: { editingSession = session }) {
            RoundedRectangle(cornerRadius: 4)
                .fill(.blue.opacity(0.6))
                .frame(width: 60, height: height)
                .offset(x: 60, y: yStart)
        }
        .buttonStyle(.plain)
    }

    private var diaperMarkers: some View {
        ForEach(todayDiapers, id: \.id) { diaper in
            Circle()
                .fill(diaper.kind == .pee ? .blue : .brown)
                .frame(width: 12, height: 12)
                .offset(x: 130, y: yOffset(for: diaper.at) - 6)
        }
    }

    private func yOffset(for date: Date) -> CGFloat {
        let minutesFromMidnight = date.timeIntervalSince(todayStart) / 60
        return CGFloat(minutesFromMidnight) * hourHeight / 60
    }
}

#Preview {
    TodayTimelineView()
        .modelContainer(for: [FeedingSession.self, DiaperEvent.self], inMemory: true)
}
```

- [ ] **Step 2: Build + tests**

Expected: 57 passed.

- [ ] **Step 3: Commit**

```bash
git add Kojeni/Kojeni/Features/History/TodayTimelineView.swift
git commit -m "feat(history): TodayTimelineView 24h vertical with session bars + diaper dots"
```

---

## Task 6: `WeeklyChartView` — Swift Charts stacked bar

**Files:**
- Modify: `Kojeni/Kojeni/Features/History/WeeklyChartView.swift`

**Cíl:** Swift Charts stacked bar chart. X = posledních 7 dní (zkrácený název dne), Y = celkové minuty kojení, barvy = L vs P stack. Přepínač nahoře: „Délka kojení" / „Počet plenek".

- [ ] **Step 1: Přepiš `WeeklyChartView`**

```swift
import SwiftUI
import Charts
import SwiftData

struct WeeklyChartView: View {

    enum Metric: String, CaseIterable, Identifiable {
        case feedingDuration = "Délka kojení"
        case diaperCount     = "Počet plenek"
        var id: String { rawValue }
    }

    @Query private var allSessions: [FeedingSession]
    @Query private var allDiapers: [DiaperEvent]
    @State private var metric: Metric = .feedingDuration

    /// Reprezentace jednoho stack data point pro chart.
    private struct DataPoint: Identifiable {
        let id = UUID()
        let day: Date
        let category: String   // "L" / "P" / "Čůrání" / "Kakání"
        let value: Double      // minuty nebo počet
    }

    private var dataPoints: [DataPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // 7 dní zpátky (dnes + 6 minulých).
        let days = (0..<7).map { cal.date(byAdding: .day, value: -$0, to: today)! }.reversed()

        switch metric {
        case .feedingDuration:
            return days.flatMap { day -> [DataPoint] in
                let dayEnd = day.addingTimeInterval(24 * 3600)
                let dailySessions = allSessions.filter {
                    $0.startedAt >= day && $0.startedAt < dayEnd && $0.endedAt != nil
                }
                var leftMinutes = 0.0
                var rightMinutes = 0.0
                for session in dailySessions {
                    for segment in session.segments() {
                        let mins = segment.end.timeIntervalSince(segment.start) / 60
                        if segment.breast == .left { leftMinutes += mins } else { rightMinutes += mins }
                    }
                }
                return [
                    DataPoint(day: day, category: "L", value: leftMinutes),
                    DataPoint(day: day, category: "P", value: rightMinutes)
                ]
            }

        case .diaperCount:
            return days.flatMap { day -> [DataPoint] in
                let dayEnd = day.addingTimeInterval(24 * 3600)
                let dailyDiapers = allDiapers.filter { $0.at >= day && $0.at < dayEnd }
                let peeCount = dailyDiapers.filter { $0.kind == .pee }.count
                let pooCount = dailyDiapers.filter { $0.kind == .poo }.count
                return [
                    DataPoint(day: day, category: "Čůrání", value: Double(peeCount)),
                    DataPoint(day: day, category: "Kakání", value: Double(pooCount))
                ]
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Metrika", selection: $metric) {
                ForEach(Metric.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Chart(dataPoints) { point in
                BarMark(
                    x: .value("Den", point.day, unit: .day),
                    y: .value(metric == .feedingDuration ? "min" : "počet", point.value)
                )
                .foregroundStyle(by: .value("Kategorie", point.category))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.short))
                }
            }
            .chartLegend(position: .bottom)
            .padding()
        }
    }
}

#Preview {
    WeeklyChartView()
        .modelContainer(for: [FeedingSession.self, DiaperEvent.self, BreastChange.self], inMemory: true)
}
```

- [ ] **Step 2: Build + tests**

Expected: 57 passed.

- [ ] **Step 3: Commit**

```bash
git add Kojeni/Kojeni/Features/History/WeeklyChartView.swift
git commit -m "feat(history): WeeklyChartView with Swift Charts stacked bar + metric switch"
```

---

## Task 7: `EditSessionSheet` — full edit experience

**Files:**
- Modify: `Kojeni/Kojeni/Features/History/EditSessionSheet.swift`

**Cíl:** Form-based sheet pro editaci sezení: startedAt, endedAt (DatePicker), initialBreast (Picker), pumpedMl (Stepper s nil podporou). Smaž tlačítko s confirmation. Save tlačítko v navigation bar.

- [ ] **Step 1: Přepiš `EditSessionSheet`**

```swift
import SwiftUI
import SwiftData

struct EditSessionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: FeedingSession

    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var initialBreast: Breast
    @State private var pumpedMl: Int
    @State private var hasPumpedMl: Bool
    @State private var showDeleteConfirm = false

    init(session: FeedingSession) {
        self.session = session
        _startedAt = State(initialValue: session.startedAt)
        _endedAt = State(initialValue: session.endedAt ?? .now)
        _initialBreast = State(initialValue: session.initialBreast)
        _pumpedMl = State(initialValue: session.pumpedMl ?? 0)
        _hasPumpedMl = State(initialValue: session.pumpedMl != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Čas") {
                    DatePicker("Začátek", selection: $startedAt)
                    DatePicker("Konec", selection: $endedAt, in: startedAt...)
                    LabeledContent("Délka", value: "\(Int(endedAt.timeIntervalSince(startedAt) / 60)) min")
                }

                Section("Prso") {
                    Picker("Začátek", selection: $initialBreast) {
                        Text("Levé").tag(Breast.left)
                        Text("Pravé").tag(Breast.right)
                    }
                    .pickerStyle(.segmented)

                    if !session.breastChanges.isEmpty {
                        Text("\(session.breastChanges.count) přepnutí prsa")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Odstříkané mléko") {
                    Toggle("Zaznamenáno", isOn: $hasPumpedMl)
                    if hasPumpedMl {
                        Stepper(value: $pumpedMl, in: 0...300, step: 5) {
                            Text("\(pumpedMl) ml")
                                .monospacedDigit()
                        }
                    }
                }

                Section {
                    Button("Smazat sezení", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Upravit sezení")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zrušit") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Uložit") { save() }
                        .bold()
                }
            }
            .confirmationDialog(
                "Opravdu smazat sezení?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Smazat", role: .destructive) { delete() }
                Button("Zrušit", role: .cancel) {}
            } message: {
                Text("Smaže i přidružená přepnutí prsa. Nelze vrátit.")
            }
        }
    }

    private func save() {
        session.startedAt = startedAt
        session.endedAt = endedAt
        session.initialBreast = initialBreast
        session.pumpedMl = hasPumpedMl ? pumpedMl : nil

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("EditSessionSheet save failed: \(error)")
            dismiss()
        }
    }

    private func delete() {
        modelContext.delete(session)
        try? modelContext.save()
        dismiss()
    }
}
```

- [ ] **Step 2: Build + tests**

Expected: 57 passed.

- [ ] **Step 3: Commit**

```bash
git add Kojeni/Kojeni/Features/History/EditSessionSheet.swift
git commit -m "feat(history): EditSessionSheet — time / breast / ml edit + delete"
```

---

## Task 8: E2E smoke + CHANGELOG + tag v0.5.0

**Files:** `CHANGELOG.md`

**Cíl:** Manuální verifikace 4 segmentů + edit/delete flow. Tag v0.5.0.

- [ ] **Step 1: Seedovat trochu dat na simulátoru**

V app projít: 2-3 sezení s ml, několik plenek (různé typy). Tím se naplní History.

- [ ] **Step 2: Manual smoke (Simulator.app)**

- [ ] Historie tab → segmented picker se 4 segmenty viditelný.
- [ ] **Dnes**: vidím vertikální timeline 24h, dnešní sezení jsou modré boxy, plenky jsou tečky.
- [ ] **Týden**: graf, stacked bar L+P barvy. Přepínač „Délka kojení" / „Počet plenek".
- [ ] **Seznam**: scroll list grupovaný po dnech („Dnes — pondělí 7. 6.", „Včera — neděle 6. 6."). Tap na sezení → EditSessionSheet.
- [ ] **Statistiky**: 6 karet s metrikami (Sezení/den, ⌀ délka, ⌀ interval, Plenek/den, Σ ml týden, Sezení celkem).
- [ ] V EditSessionSheet: změň konec sezení o +5 min → Uložit → zpět v seznamu vidíš novou délku.
- [ ] V EditSessionSheet: nastav pumpedMl na 40 → Uložit → v seznamu vidíš „40 ml".
- [ ] V EditSessionSheet: Smazat sezení → confirmation → ANO → sezení zmizí ze všech 4 segmentů.

- [ ] **Step 3: Unit testy**

Expected: **57 passed**.

- [ ] **Step 4: Update `CHANGELOG.md`**

Před `## [0.4.0]` (nebo `## [0.3.0]` pokud Plan 4 ještě neproběhl) přidej:

```markdown
## [0.5.0] — Plan 5: Historie — 2026-06-07

- `HistoryView` se segmented pickerem 4 sub-views.
- `TodayTimelineView` — 24h vertikální timeline dnešních eventů, sezení jako modré boxy, plenky jako tečky.
- `WeeklyChartView` — Swift Charts stacked bar (7 dní), přepínač metriky Délka kojení / Počet plenek.
- `SessionListView` — chronologický scroll list grupovaný po dnech, heterogeneous (sezení + plenky dohromady).
- `StatisticsView` — 6 karet (sezení/den, ⌀ délka, ⌀ interval, plenek/den, suma ml/týden, sezení celkem).
- `EditSessionSheet` — Form edit startedAt/endedAt/initialBreast/pumpedMl, smazání s confirmation.
- `HistoryStatistics` value struct + `.compute(over:)` factory (8 unit testů).
- 8 nových Swift Testing testů. Celkem 57.
```

- [ ] **Step 5: Commit + tag**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for Plan 5 history"
git tag -a v0.5.0 -m "Plan 5 (History) complete"
```

---

## Hotovo — Plan 5 dokončen

Stav po Plan 5:
- Mamka vidí všechna data co natrackovala (timeline, graf, list, stats).
- Může opravit chybnou sezení (špatně zadaný ml, špatný čas).
- Statistiky přehledně shrnují její týden.

**Známé limity Plan 5 odložené pro Plan 6:**
- Editace plenek (ne sezení) — Plan 6.
- Bulk delete / „smaž za posledních X" — Plan 6.
- Pull-to-refresh — SwiftData `@Query` to neumí přímo, akceptujeme jak je.
- Export do souboru / sdílení — out of scope.
