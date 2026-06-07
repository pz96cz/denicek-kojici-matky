import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderScheduler.self) private var reminderScheduler

    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Připomínky") {
                    if let settings {
                        Toggle("Připomínky zapnuté", isOn: Binding(
                            get: { settings.remindersEnabled },
                            set: { newValue in
                                settings.remindersEnabled = newValue
                                try? modelContext.save()
                                handleSettingsChanged(settings: settings)
                            }
                        ))

                        Stepper(
                            value: Binding(
                                get: { settings.reminderIntervalMinutes },
                                set: { newValue in
                                    settings.reminderIntervalMinutes = newValue
                                    try? modelContext.save()
                                    handleSettingsChanged(settings: settings)
                                }
                            ),
                            in: AppSettings.minIntervalMinutes...AppSettings.maxIntervalMinutes,
                            step: 15
                        ) {
                            VStack(alignment: .leading) {
                                Text("Interval mezi kojeními")
                                Text(formattedInterval(settings.reminderIntervalMinutes))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(!settings.remindersEnabled)
                    } else {
                        Text("Načítání…")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("O aplikaci") {
                    LabeledContent("Verze", value: appVersion)
                    LabeledContent("Build", value: appBuild)
                    Button("Otevřít nastavení notifikací") {
                        openAppSettings()
                    }
                }
            }
            .navigationTitle("Nastavení")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func formattedInterval(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h) h" }
        if h == 0 { return "\(m) min" }
        return "\(h) h \(m) min"
    }

    private func handleSettingsChanged(settings: AppSettings) {
        // Pokud reminders disabled, cancel pending.
        guard settings.remindersEnabled else {
            reminderScheduler.cancelPending()
            return
        }

        // Pokud enabled a existuje poslední ukončené sezení, přepláň nový reminder
        // z jeho endedAt (může být v minulosti → okamžitá delivery).
        let descriptor = FetchDescriptor<FeedingSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let recent = (try? modelContext.fetch(descriptor)) ?? []
        guard let last = recent.first(where: { $0.endedAt != nil }),
              let endedAt = last.endedAt else { return }

        Task {
            try? await reminderScheduler.scheduleAfter(
                endedAt: endedAt,
                intervalMinutes: settings.reminderIntervalMinutes
            )
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettings.self, inMemory: true)
        .environment(ReminderScheduler())
}
