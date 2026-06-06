import SwiftUI
import SwiftData

struct IdleHomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FeedingSession.endedAt, order: .reverse)
    private var allSessions: [FeedingSession]

    @State private var showBreastPicker = false
    @State private var showDiaperSheet = false

    private var lastEndedSession: FeedingSession? {
        allSessions.first { $0.endedAt != nil }
    }

    var body: some View {
        VStack(spacing: 24) {
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
        .sheet(isPresented: $showBreastPicker) {
            // BreastPickerSheet napíše Task 8.
            // Dočasný placeholder, ať jde sheet otevřít.
            Text("BreastPickerSheet (placeholder)")
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDiaperSheet) {
            // DiaperSheet napíše Task 11.
            Text("DiaperSheet (placeholder)")
                .presentationDetents([.medium])
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
}

#Preview("Empty") {
    IdleHomeView()
        .modelContainer(for: [FeedingSession.self, DiaperEvent.self], inMemory: true)
}
