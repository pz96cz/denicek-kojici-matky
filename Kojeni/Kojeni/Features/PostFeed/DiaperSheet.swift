import SwiftUI
import SwiftData

struct DiaperSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Kakání — konzistence")
                .font(.title2.bold())
                .padding(.top, 32)

            VStack(spacing: 12) {
                consistencyButton(.loose,  label: "Řídké")
                consistencyButton(.normal, label: "Normální")
                consistencyButton(.hard,   label: "Tvrdé")
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.bottom)
        .presentationDetents([.medium])
    }

    private func consistencyButton(_ consistency: PooConsistency, label: String) -> some View {
        Button(action: { log(consistency: consistency) }) {
            Text(label)
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 70)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func log(consistency: PooConsistency) {
        do {
            _ = try DiaperService(context: modelContext).logPoo(consistency: consistency)
            dismiss()
        } catch {
            print("logPoo failed: \(error)")
            dismiss()
        }
    }
}

#Preview {
    DiaperSheet()
        .modelContainer(for: DiaperEvent.self, inMemory: true)
}
