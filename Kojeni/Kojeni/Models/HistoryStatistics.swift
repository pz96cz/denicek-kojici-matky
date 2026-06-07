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
    /// Průměrný počet čůrání za den.
    var avgPeesPerDay: Double
    /// Průměrný počet kakání za den.
    var avgPoosPerDay: Double
    /// Suma odstříkaných ml v okně (jen sezení s pumpedMl != nil, sentinel -1 vyloučen).
    var totalPumpedMl: Int
    /// Počet ukončených sezení v okně.
    var sessionCount: Int
    /// Celkový počet čůrání v okně.
    var peeCount: Int
    /// Celkový počet kakání v okně.
    var pooCount: Int

    static let zero = HistoryStatistics(
        avgSessionsPerDay: 0,
        avgSessionDurationMinutes: 0,
        avgIntervalBetweenSessionsMinutes: 0,
        avgPeesPerDay: 0,
        avgPoosPerDay: 0,
        totalPumpedMl: 0,
        sessionCount: 0,
        peeCount: 0,
        pooCount: 0
    )

    /// Spočítá statistiky z poskytnutých dat za posledních `over` dní.
    /// Pouze ukončená sezení (endedAt != nil) se počítají do duration/count.
    static func compute(sessions: [FeedingSession],
                        diapers: [DiaperEvent],
                        over days: Int) -> HistoryStatistics {
        let now = Date.now
        let windowStart = now.addingTimeInterval(-Double(days) * 24 * 3600)

        let recentEnded = sessions.filter { session in
            guard let endedAt = session.endedAt else { return false }
            return endedAt >= windowStart
        }
        let recentDiapers = diapers.filter { $0.at >= windowStart }
        let recentPees = recentDiapers.filter { $0.kind == .pee }
        let recentPoos = recentDiapers.filter { $0.kind == .poo }

        guard !recentEnded.isEmpty || !recentDiapers.isEmpty else {
            return .zero
        }

        let count = recentEnded.count
        let totalDuration = recentEnded.reduce(0.0) { $0 + $1.duration }
        let avgDuration = count > 0 ? totalDuration / Double(count) / 60.0 : 0

        let sortedAsc = recentEnded
            .sorted { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
        var intervalsTotal: Double = 0
        var intervalCount = 0
        if sortedAsc.count > 1 {
            for i in 0..<(sortedAsc.count - 1) {
                guard let endedAt = sortedAsc[i].endedAt else { continue }
                let gap = sortedAsc[i+1].startedAt.timeIntervalSince(endedAt)
                if gap > 0 {
                    intervalsTotal += gap
                    intervalCount += 1
                }
            }
        }
        let avgInterval = intervalCount > 0
            ? intervalsTotal / Double(intervalCount) / 60.0 : 0

        // pumpedMl: sentinel -1 (explicitní skip — viz Plan 6 Task 4) vyloučit.
        let totalPumped = recentEnded
            .compactMap { $0.pumpedMl }
            .filter { $0 >= 0 }
            .reduce(0, +)

        let denominator = max(Double(days), 1)
        let avgSessions = Double(count) / denominator
        let avgPees = Double(recentPees.count) / denominator
        let avgPoos = Double(recentPoos.count) / denominator

        return HistoryStatistics(
            avgSessionsPerDay: avgSessions,
            avgSessionDurationMinutes: avgDuration,
            avgIntervalBetweenSessionsMinutes: avgInterval,
            avgPeesPerDay: avgPees,
            avgPoosPerDay: avgPoos,
            totalPumpedMl: totalPumped,
            sessionCount: count,
            peeCount: recentPees.count,
            pooCount: recentPoos.count
        )
    }
}
