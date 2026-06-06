import SwiftUI

struct ActiveSessionView: View {
    let session: FeedingSession

    var body: some View {
        VStack {
            Text("Active (placeholder)")
            Text("Started: \(session.startedAt.formatted(.iso8601))")
        }
    }
}
