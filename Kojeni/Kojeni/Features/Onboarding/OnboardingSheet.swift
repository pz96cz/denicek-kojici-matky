import SwiftUI
import SwiftData

struct OnboardingSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ReminderScheduler.self) private var reminderScheduler

    @State private var intervalMinutes: Int = AppSettings.defaultIntervalMinutes

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("Vítej v Kojení 🤱")
                    .font(.largeTitle.bold())
                Text("Po každém kojení ti připomeneme další krmení.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Text("Jak často chceš připomenout?")
                    .font(.headline)
                Stepper(value: $intervalMinutes,
                        in: AppSettings.minIntervalMinutes...AppSettings.maxIntervalMinutes,
                        step: 15) {
                    Text(formattedInterval)
                        .font(.title2.monospacedDigit())
                }
                .padding(.horizontal)
            }

            Spacer()

            Button(action: saveAndClose) {
                Text("Hotovo")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
        .interactiveDismissDisabled()
    }

    private var formattedInterval: String {
        let hours = intervalMinutes / 60
        let minutes = intervalMinutes % 60
        if minutes == 0 {
            return "\(hours) h"
        } else if hours == 0 {
            return "\(minutes) min"
        } else {
            return "\(hours) h \(minutes) min"
        }
    }

    private func saveAndClose() {
        Task {
            do {
                let settings = try AppSettings.loadOrCreate(in: modelContext)
                settings.reminderIntervalMinutes = intervalMinutes

                let granted = (try? await reminderScheduler.requestAuthorization()) ?? false
                settings.remindersEnabled = granted

                try modelContext.save()
                dismiss()
            } catch {
                print("OnboardingSheet save failed: \(error)")
                dismiss()
            }
        }
    }
}

#Preview {
    OnboardingSheet()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
