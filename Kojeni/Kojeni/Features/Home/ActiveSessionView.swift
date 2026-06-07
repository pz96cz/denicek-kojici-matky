import SwiftUI
import SwiftData

struct ActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LiveActivityManager.self) private var liveActivity
    @Environment(ReminderScheduler.self) private var reminderScheduler

    @Query private var settingsList: [AppSettings]

    let session: FeedingSession

    @State private var showPumpedMlSheet = false
    @State private var endedSessionID: PersistentIdentifier?
    @State private var showNoteSheet = false
    @State private var showPumpedMlInline = false

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

            HStack(spacing: 10) {
                noteRow
                pumpedMlRow
            }
            .padding(.horizontal)

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
        .sheet(isPresented: $showNoteSheet) {
            NoteSheet(session: session)
        }
        .sheet(isPresented: $showPumpedMlInline) {
            PumpedMlSheet(sessionID: session.persistentModelID)
        }
        .sheet(isPresented: $showPumpedMlSheet) {
            if let id = endedSessionID {
                PumpedMlSheet(sessionID: id)
            }
        }
    }

    /// Karta pro poznámku — preview pokud existuje, jinak prompt.
    private var noteRow: some View {
        Button(action: { showNoteSheet = true }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: hasNote ? "note.text" : "square.and.pencil")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                    Text("Poznámka")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                if let note = session.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("Přidat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// Karta pro odstříknuté mléko — ml hodnotu pokud zadaná, jinak prompt.
    private var pumpedMlRow: some View {
        Button(action: { showPumpedMlInline = true }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: hasPumpedMl ? "drop.fill" : "drop")
                        .foregroundStyle(.cyan)
                        .font(.subheadline)
                    Text("Odstříknuto")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                if let ml = session.pumpedMl, ml >= 0 {
                    Text("\(ml) ml")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.primary)
                } else {
                    Text("Přidat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var hasNote: Bool { (session.note ?? "").isEmpty == false }
    private var hasPumpedMl: Bool {
        if let ml = session.pumpedMl { return ml >= 0 }
        return false
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
            if let settings = settingsList.first, settings.remindersEnabled,
               let endedAt = ended.endedAt {
                Task {
                    try? await reminderScheduler.scheduleAfter(
                        endedAt: endedAt,
                        intervalMinutes: settings.reminderIntervalMinutes
                    )
                }
            }
        } catch {
            print("endSession failed: \(error)")
        }
    }
}
