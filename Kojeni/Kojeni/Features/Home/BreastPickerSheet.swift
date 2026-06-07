import SwiftUI
import SwiftData

struct BreastPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LiveActivityManager.self) private var liveActivity

    @Query(sort: \FeedingSession.endedAt, order: .reverse)
    private var allSessions: [FeedingSession]

    private var suggestedBreast: Breast {
        // Default: opačné než poslední aktivně použité prso minulého sezení.
        // Pokud žádné předchozí, default .left.
        guard let last = allSessions.first(where: { $0.endedAt != nil }) else {
            return .left
        }
        return last.currentBreast.opposite
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Které prso?")
                .font(.title2.bold())
                .padding(.top, 32)

            VStack(spacing: 16) {
                breastButton(for: .left)
                breastButton(for: .right)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.bottom)
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func breastButton(for breast: Breast) -> some View {
        let label = Text(self.label(for: breast))
            .font(.system(size: 26, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 80)
        if suggestedBreast == breast {
            Button(action: { start(with: breast) }) { label }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        } else {
            Button(action: { start(with: breast) }) { label }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }

    private func label(for breast: Breast) -> String {
        switch breast {
        case .left:  return "Levé"
        case .right: return "Pravé"
        }
    }

    private func start(with breast: Breast) {
        do {
            let session = try FeedingService(context: modelContext).startSession(breast: breast)
            // Start Live Activity — sessionID jako string z PersistentIdentifier
            let sessionID = String(describing: session.persistentModelID)
            liveActivity.start(
                sessionID: sessionID,
                startedAt: session.startedAt,
                currentBreast: breast
            )
            dismiss()
        } catch {
            print("startSession failed: \(error)")
            dismiss()
        }
    }
}

#Preview {
    BreastPickerSheet()
        .modelContainer(for: [FeedingSession.self, BreastChange.self], inMemory: true)
}
