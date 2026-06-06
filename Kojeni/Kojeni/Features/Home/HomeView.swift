import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            Text("Domů")
                .navigationTitle("Domů")
        }
    }
}

#Preview {
    HomeView()
}
