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
                TrainingHubView()
            }
            .tabItem {
                Label("Training", systemImage: "figure.strengthtraining.traditional")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
        }
        .tint(AppPalette.clay)
    }
}
