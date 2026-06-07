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
                .fill(diaper.kind == .pee ? Color.blue : Color.brown)
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
