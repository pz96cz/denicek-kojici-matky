import SwiftUI
import SwiftData

struct IdleHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderScheduler.self) private var reminderScheduler

    @Query(sort: \FeedingSession.endedAt, order: .reverse)
    private var allSessions: [FeedingSession]

    @Query(sort: \DiaperEvent.at, order: .reverse)
    private var allDiapers: [DiaperEvent]

    @Query private var settingsList: [AppSettings]

    @State private var showBreastPicker = false
    @State private var showDiaperSheet = false
    @State private var authorizationDenied = false

    // Toast / feedback
    @State private var toastText: String?
    @State private var toastIcon: String = "checkmark.circle.fill"
    @State private var toastTask: Task<Void, Never>?
    @State private var lastSeenDiaperID: PersistentIdentifier?
    @State private var feedbackTrigger = 0

    private var lastEndedSession: FeedingSession? {
        allSessions.first { $0.endedAt != nil }
    }

    private var settings: AppSettings? { settingsList.first }

    private var nextFeedingDue: Date? {
        guard let last = lastEndedSession,
              let endedAt = last.endedAt,
              let interval = settings?.reminderIntervalMinutes else { return nil }
        return endedAt.addingTimeInterval(TimeInterval(interval * 60))
    }

    // MARK: - Today's diaper stats

    private var todayStart: Date { Calendar.current.startOfDay(for: .now) }
    private var todayDiapers: [DiaperEvent] {
        allDiapers.filter { $0.at >= todayStart }
    }
    private var todayPeeCount: Int { todayDiapers.filter { $0.kind == .pee }.count }
    private var todayPooCount: Int { todayDiapers.filter { $0.kind == .poo }.count }
    private var lastPeeToday: DiaperEvent? { todayDiapers.first { $0.kind == .pee } }
    private var lastPooToday: DiaperEvent? { todayDiapers.first { $0.kind == .poo } }

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
        .scrollIndicators(.automatic)
        .overlay(alignment: .top) {
            if let toastText {
                toastView(text: toastText, icon: toastIcon)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 4)
                    .allowsHitTesting(false)   // toast nesmí blokovat tapy/scroll
            }
        }
        .animation(.spring(duration: 0.3), value: toastText)
        .sensoryFeedback(.success, trigger: feedbackTrigger)
        .task {
            await checkAuthorization()
            lastSeenDiaperID = allDiapers.first?.persistentModelID
        }
        .onChange(of: allDiapers.first?.persistentModelID) { _, newID in
            // Spawn toast pro každý nově přidaný DiaperEvent (i z DiaperSheet)
            guard let newID, newID != lastSeenDiaperID else { return }
            lastSeenDiaperID = newID
            if let newest = allDiapers.first {
                let toastForKind = newest.kind == .pee ? "Čůrání zaznamenáno" : "Kakání zaznamenáno"
                showToast(toastForKind, icon: newest.kind == .pee ? "drop.fill" : "circle.hexagongrid.fill")
            }
        }
        .sheet(isPresented: $showBreastPicker) { BreastPickerSheet() }
        .sheet(isPresented: $showDiaperSheet) { DiaperSheet() }
    }

    // MARK: - Toast

    private func showToast(_ text: String, icon: String) {
        toastText = text
        toastIcon = icon
        feedbackTrigger &+= 1
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if !Task.isCancelled {
                toastText = nil
            }
        }
    }

    private func toastView(text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white)
            Text(text)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(.green.gradient)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }

    // MARK: - Last feeding card

    @ViewBuilder
    private var lastFeedingCard: some View {
        if let last = lastEndedSession, let endedAt = last.endedAt {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Poslední kojení", systemImage: "figure.and.child.holdinghands")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(relativeAgo(from: endedAt))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

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

                breastBreakdown(for: last)

                Divider()

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

    // MARK: - Kojit button

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
            HStack {
                Text("Plenky")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Dnes")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                diaperCard(
                    label: "Čůrání",
                    icon: "drop.fill",
                    tint: .blue,
                    count: todayPeeCount,
                    lastAt: lastPeeToday?.at,
                    action: logPee
                )

                diaperCard(
                    label: "Kakání",
                    icon: "circle.hexagongrid.fill",
                    tint: .brown,
                    count: todayPooCount,
                    lastAt: lastPooToday?.at,
                    action: { showDiaperSheet = true }
                )
            }
            .padding(.horizontal)
        }
    }

    private func diaperCard(label: String,
                            icon: String,
                            tint: Color,
                            count: Int,
                            lastAt: Date?,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline)
                    Text(label)
                        .font(.subheadline.bold())
                }

                HStack(spacing: 6) {
                    Text("\(count)×")
                        .font(.title2.bold().monospacedDigit())
                    if let lastAt {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(timeOnly(lastAt))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("dnes 0×")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .tint(tint)
        .buttonStyle(.bordered)
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

    private func timeOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func timeRange(start: Date, end: Date) -> String {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.dateFormat = "HH:mm"
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
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
            // Toast/haptic se spustí přes .onChange(of: allDiapers.first?.id) níže.
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
