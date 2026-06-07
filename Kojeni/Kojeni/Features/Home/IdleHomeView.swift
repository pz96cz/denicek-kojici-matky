import SwiftUI
import SwiftData

struct IdleHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderScheduler.self) private var reminderScheduler

    @Query(sort: \FeedingSession.endedAt, order: .reverse)
    private var allSessions: [FeedingSession]

    @Query private var settingsList: [AppSettings]

    @State private var showBreastPicker = false
    @State private var showDiaperSheet = false
    @State private var authorizationDenied = false

    private var lastEndedSession: FeedingSession? {
        allSessions.first { $0.endedAt != nil }
    }

    private var settings: AppSettings? { settingsList.first }

    /// Čas dalšího kojení = endedAt + interval
    private var nextFeedingDue: Date? {
        guard let last = lastEndedSession,
              let endedAt = last.endedAt,
              let interval = settings?.reminderIntervalMinutes else { return nil }
        return endedAt.addingTimeInterval(TimeInterval(interval * 60))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if authorizationDenied {
                    permissionBanner
                }

                lastFeedingCard

                kojitButton
                    .padding(.horizontal)
                    .padding(.top, 4)

                diaperSection
                    .padding(.top, 4)
            }
            .padding(.vertical)
        }
        .task { await checkAuthorization() }
        .sheet(isPresented: $showBreastPicker) { BreastPickerSheet() }
        .sheet(isPresented: $showDiaperSheet) { DiaperSheet() }
    }

    // MARK: - Last feeding card

    @ViewBuilder
    private var lastFeedingCard: some View {
        if let last = lastEndedSession, let endedAt = last.endedAt {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Label("Poslední kojení", systemImage: "figure.and.child.holdinghands")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(relativeAgo(from: endedAt))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                // Časový interval kojení
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text(timeRange(start: last.startedAt, end: endedAt))
                        .font(.title3.monospacedDigit().bold())
                    Spacer()
                    Text(durationFormatted(last.duration))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                // Doba na každém prsu
                breastBreakdown(for: last)

                Divider()

                // Další kojení
                nextFeedingRow
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "moon.zzz")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("Zatím žádné kojení")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Tap „Kojit“ když začneš.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func breastBreakdown(for session: FeedingSession) -> some View {
        let durations = breastDurations(for: session)
        let totalSecs = max(durations.left + durations.right, 1)

        VStack(spacing: 8) {
            breastBar(label: "Levé", color: .blue,
                      seconds: durations.left,
                      fraction: durations.left / totalSecs)
            breastBar(label: "Pravé", color: .purple,
                      seconds: durations.right,
                      fraction: durations.right / totalSecs)
        }
    }

    private func breastBar(label: String, color: Color, seconds: Double, fraction: Double) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .frame(width: 48, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.7))
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 8)
            Text(durationFormatted(seconds))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var nextFeedingRow: some View {
        if let next = nextFeedingDue {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                Text("Další kojení")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(absoluteTime(next))
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.primary)
                    Text(relativeFuture(to: next))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Kojit button (zmenšeno)

    private var kojitButton: some View {
        Button(action: { showBreastPicker = true }) {
            Label("Kojit", systemImage: "play.fill")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    // MARK: - Diaper section

    private var diaperSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Plenky")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            HStack(spacing: 10) {
                Button(action: logPee) {
                    Label("Čůrání", systemImage: "drop.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button(action: { showDiaperSheet = true }) {
                    Label("Kakání", systemImage: "circle.hexagongrid.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.bordered)
                .tint(.brown)
            }
            .padding(.horizontal)
        }
    }

    private var permissionBanner: some View {
        VStack(spacing: 4) {
            Text("⚠️ Notifikace jsou vypnuté v systému")
                .font(.subheadline.bold())
            Text("Reminder kojení nemůže fungovat, dokud je nepovolíš.")
                .font(.caption)
            Button("Otevřít nastavení") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .foregroundStyle(.orange)
        .padding(8)
        .background(.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func breastDurations(for session: FeedingSession) -> (left: Double, right: Double) {
        var left: Double = 0
        var right: Double = 0
        for seg in session.segments() {
            let secs = seg.end.timeIntervalSince(seg.start)
            switch seg.breast {
            case .left:  left += secs
            case .right: right += secs
            }
        }
        return (left, right)
    }

    private func durationFormatted(_ seconds: Double) -> String {
        let mins = Int(seconds / 60)
        if mins < 1 { return "<1 min" }
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60
        let m = mins % 60
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) min"
    }

    private func timeRange(start: Date, end: Date) -> String {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.dateFormat = "HH:mm"
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        // Pokud start a end jsou ve stejný den → "14:32–14:47"
        // Jinak → "Včera 23:15 – Dnes 00:08"
        if cal.isDate(start, inSameDayAs: end) {
            return "\(startStr) – \(endStr)"
        }
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "cs_CZ")
        dayFormatter.dateFormat = "d. M."
        let startDay = dayLabel(for: start, dayFormatter: dayFormatter)
        let endDay = dayLabel(for: end, dayFormatter: dayFormatter)
        return "\(startDay) \(startStr) – \(endDay) \(endStr)"
    }

    private func dayLabel(for date: Date, dayFormatter: DateFormatter) -> String {
        if Calendar.current.isDateInToday(date) { return "Dnes" }
        if Calendar.current.isDateInYesterday(date) { return "Včera" }
        return dayFormatter.string(from: date)
    }

    private func absoluteTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        if Calendar.current.isDateInTomorrow(date) {
            formatter.dateFormat = "HH:mm"
            return "Zítra \(formatter.string(from: date))"
        }
        formatter.dateFormat = "d. M. HH:mm"
        return formatter.string(from: date)
    }

    private func relativeAgo(from date: Date) -> String {
        let secs = Date.now.timeIntervalSince(date)
        if secs < 60 { return "před chvílí" }
        if secs < 3600 { return "před \(Int(secs/60)) min" }
        let h = Int(secs/3600)
        let m = Int(secs/60) % 60
        if h < 24 {
            if m == 0 { return "před \(h) h" }
            return "před \(h) h \(m) min"
        }
        let days = h / 24
        return "před \(days) dny"
    }

    private func relativeFuture(to date: Date) -> String {
        let secs = date.timeIntervalSinceNow
        if secs < 0 { return "už by mělo být" }
        if secs < 60 { return "za chvíli" }
        if secs < 3600 { return "za \(Int(secs/60)) min" }
        let h = Int(secs/3600)
        let m = Int(secs/60) % 60
        if h < 24 {
            if m == 0 { return "za \(h) h" }
            return "za \(h) h \(m) min"
        }
        return "za více než den"
    }

    private func logPee() {
        do {
            try DiaperService(context: modelContext).logPee()
        } catch {
            print("logPee failed: \(error)")
        }
    }

    private func checkAuthorization() async {
        guard let settings = settingsList.first, settings.remindersEnabled else {
            authorizationDenied = false
            return
        }
        let isAuth = await reminderScheduler.isAuthorized()
        authorizationDenied = !isAuth
    }
}

#Preview("Empty") {
    IdleHomeView()
        .modelContainer(for: [FeedingSession.self, DiaperEvent.self, AppSettings.self], inMemory: true)
        .environment(LiveActivityManager())
        .environment(ReminderScheduler())
}

#Preview("With data") {
    let container = try! ModelContainer(
        for: FeedingSession.self, BreastChange.self, DiaperEvent.self, AppSettings.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let settings = AppSettings(reminderIntervalMinutes: 180)
    context.insert(settings)
    let session = FeedingSession(
        startedAt: Date.now.addingTimeInterval(-90 * 60),
        initialBreast: .left
    )
    session.endedAt = Date.now.addingTimeInterval(-75 * 60)
    let change = BreastChange(at: Date.now.addingTimeInterval(-82 * 60), to: .right)
    change.session = session
    session.breastChanges.append(change)
    context.insert(session)
    try! context.save()

    return IdleHomeView()
        .modelContainer(container)
        .environment(LiveActivityManager())
        .environment(ReminderScheduler())
}
