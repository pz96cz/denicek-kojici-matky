import SwiftUI
import SwiftData

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
