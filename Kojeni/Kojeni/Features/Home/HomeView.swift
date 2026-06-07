import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(filter: #Predicate<FeedingSession> { $0.endedAt == nil })
    private var activeSessions: [FeedingSession]

    var body: some View {
        NavigationStack {
            Group {
                if let session = activeSessions.first {
                    ActiveSessionView(session: session)
                } else {
                    IdleHomeView()
                }
            }
            .navigationTitle("Domů")
        }
    }
}

#Preview("Idle") {
    HomeView()
        .modelContainer(for: FeedingSession.self, inMemory: true)
        .environment(LiveActivityManager())
}
