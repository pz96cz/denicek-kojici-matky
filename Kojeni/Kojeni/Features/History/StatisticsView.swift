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
