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
        #expect(stats.avgPeesPerDay == 0)
        #expect(stats.avgPoosPerDay == 0)
        #expect(stats.peeCount == 0)
        #expect(stats.pooCount == 0)
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
        // V okně 7 dní (compute() filtruje na last 7d od now) — proto t0 leží
        // v rámci posledních dnů, ne na epoch.
        let t0 = Date.now.addingTimeInterval(-24 * 3600)  // 24h ago
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

    @Test func avgPeesPerDay_simple() {
        let now = Date.now
        let diapers = (0..<14).map { i in
            DiaperEvent(at: now.addingTimeInterval(-Double(i * 12 * 3600)), kind: .pee)
        }
        let stats = HistoryStatistics.compute(sessions: [], diapers: diapers, over: 7)
        #expect(stats.avgPeesPerDay == 2.0)
        #expect(stats.avgPoosPerDay == 0)
        #expect(stats.peeCount == 14)
        #expect(stats.pooCount == 0)
    }

    @Test func splits_pee_and_poo_counts() {
        let now = Date.now
        var diapers: [DiaperEvent] = []
        // 7 čůrání, 3 kakání
        for i in 0..<7 {
            diapers.append(DiaperEvent(at: now.addingTimeInterval(-Double(i * 3600)), kind: .pee))
        }
        for i in 0..<3 {
            diapers.append(DiaperEvent(at: now.addingTimeInterval(-Double(i * 3600)), kind: .poo, consistency: .normal))
        }
        let stats = HistoryStatistics.compute(sessions: [], diapers: diapers, over: 7)
        #expect(stats.peeCount == 7)
        #expect(stats.pooCount == 3)
        #expect(stats.avgPeesPerDay == 1.0)
        #expect(abs(stats.avgPoosPerDay - 3.0/7.0) < 0.001)
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
