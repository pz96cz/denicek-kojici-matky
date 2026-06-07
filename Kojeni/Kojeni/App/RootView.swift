import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsList: [AppSettings]

    @State private var showOnboarding = false
    @State private var pumpedMlPickupSessionID: PersistentIdentifier?
    @State private var showPickupSheet = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Domů", systemImage: "house.fill") }
            HistoryView()
                .tabItem { Label("Historie", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Nastavení", systemImage: "gearshape.fill") }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet()
        }
        .sheet(isPresented: $showPickupSheet) {
            if let id = pumpedMlPickupSessionID {
                PumpedMlSheet(sessionID: id)
            }
        }
        .task { handleInitialState() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                handleAppGroupPickup()
            }
        }
    }

    private func handleInitialState() {
        if settingsList.isEmpty {
            showOnboarding = true
        }
        // Při prvním spuštění také zkontroluj pickup
        handleAppGroupPickup()
    }

    private func handleAppGroupPickup() {
        // Pickup z UserDefaults.standard — App Group nelze sdílet přes AltStore re-sign
        // na free Apple ID. Intenty (openAppWhenRun) běží v main procesu, takže
        // standard suite je pro routing dostatečný.
        let defaults: UserDefaults? = .standard

        // Pickup: notifikace "Krmím teď" → startni sezení s default prsem
        if defaults?.bool(forKey: "pendingStartFromReminder") == true {
            defaults?.set(false, forKey: "pendingStartFromReminder")
            startFromReminder()
        }

        guard defaults?.bool(forKey: "pendingPumpedMlSheet") == true else { return }

        defaults?.set(false, forKey: "pendingPumpedMlSheet")
        let endedAtRaw = defaults?.double(forKey: "pendingPumpedMlSheet.endedAt") ?? 0
        guard endedAtRaw > 0 else { return }

        // Explicit fresh fetch — neopírám se o @Query, který může být stale
        // po cross-process zápisu z widget procesu.
        let target = Date(timeIntervalSinceReferenceDate: endedAtRaw)
        let descriptor = FetchDescriptor<FeedingSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let candidates = (try? modelContext.fetch(descriptor)) ?? []
        let candidate = candidates.first { session in
            guard let endedAt = session.endedAt else { return false }
            return abs(endedAt.timeIntervalSince(target)) < 5.0 && session.pumpedMl == nil
        }
        if let candidate {
            pumpedMlPickupSessionID = candidate.persistentModelID
            showPickupSheet = true
        }
    }

    private func startFromReminder() {
        // Default prso: opačné než poslední session, fallback .left.
        let descriptor = FetchDescriptor<FeedingSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let recent = (try? modelContext.fetch(descriptor)) ?? []
        let suggested: Breast = recent.first(where: { $0.endedAt != nil })?.currentBreast.opposite ?? .left
        do {
            _ = try FeedingService(context: modelContext).startSession(breast: suggested)
        } catch {
            print("startFromReminder failed: \(error)")
        }
    }
}
