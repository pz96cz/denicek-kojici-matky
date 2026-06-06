import SwiftUI

struct RootView: View {
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
    }
}
