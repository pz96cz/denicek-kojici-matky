import SwiftUI
import SwiftData

struct PumpedMlSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let sessionID: PersistentIdentifier

    @State private var ml: Int = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Odstříkané mléko")
                .font(.title2.bold())
                .padding(.top, 32)

            Text("Kolik ml jsi odstříkla po kojení?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Stepper(value: $ml, in: 0...300, step: 5) {
                Text("\(ml) ml")
                    .font(.system(size: 36, weight: .bold).monospacedDigit())
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button(action: save) {
                    Text("Uložit")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: skip) {
                    Text("Přeskočit")
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .presentationDetents([.medium])
    }

    private func save() {
        do {
            if let session = modelContext.model(for: sessionID) as? FeedingSession {
                session.pumpedMl = ml
                try modelContext.save()
            }
            dismiss()
        } catch {
            print("PumpedMlSheet save failed: \(error)")
            dismiss()
        }
    }

    private func skip() {
        dismiss()
    }
}
