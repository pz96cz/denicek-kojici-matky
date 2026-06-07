import SwiftUI

struct EditSessionSheet: View {
    let session: FeedingSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Text("Edit session (placeholder)")
        Button("Zavřít") { dismiss() }
    }
}
