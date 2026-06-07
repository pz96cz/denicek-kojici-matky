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

                sectionHeader("Kojení")
                LazyVGrid(columns: gridCols, spacing: 12) {
                    statCard(title: "Sezení/den",
                             value: formatted(stats.avgSessionsPerDay, decimals: 1))
                    statCard(title: "⌀ délka",
                             value: "\(Int(stats.avgSessionDurationMinutes.rounded())) min")
                    statCard(title: "⌀ interval",
                             value: formattedInterval(Int(stats.avgIntervalBetweenSessionsMinutes.rounded())))
                    statCard(title: "Σ ml týden",
                             value: "\(stats.totalPumpedMl) ml")
                    statCard(title: "Sezení celkem",
                             value: "\(stats.sessionCount)")
                }
                .padding(.horizontal)

                sectionHeader("Vyprázdňování")
                LazyVGrid(columns: gridCols, spacing: 12) {
                    statCard(title: "Počet čůrání",
                             value: "\(stats.peeCount)",
                             tint: .blue)
                    statCard(title: "Počet kakání",
                             value: "\(stats.pooCount)",
                             tint: .brown)
                    statCard(title: "⌀ čůrání/den",
                             value: formatted(stats.avgPeesPerDay, decimals: 1),
                             tint: .blue)
                    statCard(title: "⌀ kakání/den",
                             value: formatted(stats.avgPoosPerDay, decimals: 1),
                             tint: .brown)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private var gridCols: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 4)
    }

    private func statCard(title: String, value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(tint == .primary ? Color.primary : tint)
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
