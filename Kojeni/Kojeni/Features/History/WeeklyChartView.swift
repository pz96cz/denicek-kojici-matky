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
                    DataPoint(day: day, category: "Levé prso", value: leftMinutes),
                    DataPoint(day: day, category: "Pravé prso", value: rightMinutes)
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

    /// Custom barvy odpovídající Idle home view (modrá L / fialová P, modrá Čůrání / hnědá Kakání).
    private var colorMapping: KeyValuePairs<String, Color> {
        switch metric {
        case .feedingDuration:
            return ["Levé prso": .blue, "Pravé prso": .purple]
        case .diaperCount:
            return ["Čůrání": .blue, "Kakání": .brown]
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
                .position(by: .value("Kategorie", point.category))   // side-by-side, ne stacked
                .foregroundStyle(by: .value("Kategorie", point.category))
                .cornerRadius(3)
            }
            .chartForegroundStyleScale(colorMapping)
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
