import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Domů", systemImage: "house.fill")
                }

            HistoryView()
                .tabItem {
                    Label("Historie", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Nastavení", systemImage: "gearshape.fill")
                }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet()
        }
        .task {
            if settingsList.isEmpty {
                showOnboarding = true
            }
        }
    }
}
