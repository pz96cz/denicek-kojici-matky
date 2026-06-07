import SwiftUI
import SwiftData

struct EditSessionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: FeedingSession

    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var initialBreast: Breast
    @State private var pumpedMl: Int
    @State private var hasPumpedMl: Bool
    @State private var note: String
    @State private var showDeleteConfirm = false

    init(session: FeedingSession) {
        self.session = session
        _startedAt = State(initialValue: session.startedAt)
        _endedAt = State(initialValue: session.endedAt ?? .now)
        _initialBreast = State(initialValue: session.initialBreast)
        _pumpedMl = State(initialValue: session.pumpedMl ?? 0)
        _hasPumpedMl = State(initialValue: session.pumpedMl != nil)
        _note = State(initialValue: session.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Čas") {
                    DatePicker("Začátek", selection: $startedAt)
                    DatePicker("Konec", selection: $endedAt, in: startedAt...)
                    LabeledContent("Délka", value: "\(Int(endedAt.timeIntervalSince(startedAt) / 60)) min")
                }

                Section("Prso") {
                    Picker("Začátek", selection: $initialBreast) {
                        Text("Levé").tag(Breast.left)
                        Text("Pravé").tag(Breast.right)
                    }
                    .pickerStyle(.segmented)

                    if !session.breastChanges.isEmpty {
                        Text("\(session.breastChanges.count) přepnutí prsa")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Odstříkané mléko") {
                    Toggle("Zaznamenáno", isOn: $hasPumpedMl)
                    if hasPumpedMl {
                        Stepper(value: $pumpedMl, in: 0...300, step: 5) {
                            Text("\(pumpedMl) ml")
                                .monospacedDigit()
                        }
                    }
                }

                Section("Poznámka") {
                    TextField("Poznámka k sezení (volitelné)",
                              text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button("Smazat sezení", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Upravit sezení")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zrušit") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Uložit") { save() }
                        .bold()
                }
            }
            .confirmationDialog(
                "Opravdu smazat sezení?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Smazat", role: .destructive) { delete() }
                Button("Zrušit", role: .cancel) {}
            } message: {
                Text("Smaže i přidružená přepnutí prsa. Nelze vrátit.")
            }
        }
    }

    private func save() {
        session.startedAt = startedAt
        session.endedAt = endedAt
        session.initialBreast = initialBreast
        session.pumpedMl = hasPumpedMl ? pumpedMl : nil
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        session.note = trimmedNote.isEmpty ? nil : trimmedNote

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("EditSessionSheet save failed: \(error)")
            dismiss()
        }
    }

    private func delete() {
        modelContext.delete(session)
        try? modelContext.save()
        dismiss()
    }
}
