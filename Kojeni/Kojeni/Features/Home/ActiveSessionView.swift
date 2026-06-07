import SwiftUI
import SwiftData

struct ActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LiveActivityManager.self) private var liveActivity

    let session: FeedingSession

    @State private var showPumpedMlSheet = false
    @State private var endedSessionID: PersistentIdentifier?

    private var sessionOverEightHours: Bool {
        Date.now.timeIntervalSince(session.startedAt) > 8 * 3600
    }

    var body: some View {
        VStack(spacing: 32) {
            if sessionOverEightHours {
                VStack(spacing: 4) {
                    Text("⚠️ Sezení běží déle než 8 hodin")
                        .font(.subheadline.bold())
                    Text("Live Activity vypršela. Zkontroluj a případně uprav.")
                        .font(.caption)
                }
                .foregroundStyle(.orange)
                .padding(8)
                .background(.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }

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
            if let id = endedSessionID {
                PumpedMlSheet(sessionID: id)
            }
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
            guard let newBreast = try FeedingService(context: modelContext).switchBreast()
            else { return }
            Task { await liveActivity.update(currentBreast: newBreast) }
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
            Task { await liveActivity.end() }
        } catch {
            print("endSession failed: \(error)")
        }
    }
}
