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

    var body: some View {
        VStack(spacing: 24) {
            if authorizationDenied {
                permissionBanner
            }

            lastFeedingHeader
                .padding(.top)

            Spacer()

            Button(action: { showBreastPicker = true }) {
                Text("Kojit")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()

            diaperSection
                .padding(.bottom)
        }
        .task {
            await checkAuthorization()
        }
        .sheet(isPresented: $showBreastPicker) {
            BreastPickerSheet()
        }
        .sheet(isPresented: $showDiaperSheet) {
            DiaperSheet()
        }
    }

    @ViewBuilder
    private var lastFeedingHeader: some View {
        if let last = lastEndedSession, let endedAt = last.endedAt {
            VStack(spacing: 4) {
                Text("Poslední kojení")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(endedAt, style: .relative)
                    .font(.title3.monospacedDigit())
            }
        } else {
            Text("Zatím žádné kojení")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var diaperSection: some View {
        VStack(spacing: 12) {
            Text("Plenky")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(action: logPee) {
                    Label("Čůrání", systemImage: "drop.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.bordered)

                Button(action: { showDiaperSheet = true }) {
                    Label("Kakání", systemImage: "circle.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
    }

    private func logPee() {
        do {
            try DiaperService(context: modelContext).logPee()
        } catch {
            print("logPee failed: \(error)")
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
