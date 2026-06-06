import SwiftUI
import SwiftData

struct ActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext

    let session: FeedingSession

    @State private var showPumpedMlSheet = false
    @State private var endedSessionID: PersistentIdentifier?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Prso: \(label(for: session.currentBreast))")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(timerInterval: session.startedAt...Date.distantFuture,
                 countsDown: false)
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .monospacedDigit()

            Spacer()

            VStack(spacing: 12) {
                Button(action: switchBreast) {
                    Text("Přehodit prso")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(role: .destructive, action: endSession) {
                    Text("Stop")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .sheet(isPresented: $showPumpedMlSheet) {
            // PumpedMlSheet vznikne v Task 10.
            // Placeholder dokud sheet neexistuje:
            Text("PumpedMlSheet (placeholder)")
                .presentationDetents([.medium])
        }
    }

    private func label(for breast: Breast) -> String {
        switch breast {
        case .left:  return "Levé"
        case .right: return "Pravé"
        }
    }

    private func switchBreast() {
        do {
            _ = try FeedingService(context: modelContext).switchBreast()
        } catch {
            print("switchBreast failed: \(error)")
        }
    }

    private func endSession() {
        do {
            guard let ended = try FeedingService(context: modelContext).endSession()
            else { return }   // idempotent no-op — žádná sezení k ukončení
            endedSessionID = ended.persistentModelID
            showPumpedMlSheet = true
        } catch {
            print("endSession failed: \(error)")
        }
    }
}
