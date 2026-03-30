import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("Today", systemImage: "sun.max.fill")
            }

            NavigationStack {
                PracticeView()
            }
            .tabItem {
                Label("Practice", systemImage: "book.closed.fill")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar.fill")
            }
        }
    }
}
