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
                    Image(systemName: "person.fill")
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
