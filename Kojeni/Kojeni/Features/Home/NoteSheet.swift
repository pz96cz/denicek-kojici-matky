import SwiftUI
import SwiftData

/// Sheet pro přidání/úpravu poznámky k aktivnímu nebo ukončenému sezení.
struct NoteSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: FeedingSession

    @State private var text: String
    @FocusState private var focused: Bool

    init(session: FeedingSession) {
        self.session = session
        _text = State(initialValue: session.note ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cokoliv si chceš zapamatovat — jak miminko pilo, nálada, kontext…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 4)

                TextEditor(text: $text)
                    .focused($focused)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity)

                Spacer(minLength: 0)
            }
            .padding(.bottom)
            .navigationTitle("Poznámka")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zrušit") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Uložit") { save() }
                        .bold()
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        session.note = trimmed.isEmpty ? nil : trimmed
        try? modelContext.save()
        dismiss()
    }
}
