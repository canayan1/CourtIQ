import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DailyTipView()
                .tabItem {
                    Label(String(localized: "Daily Tip"), systemImage: "lightbulb.fill")
                }

            QuizListView()
                .tabItem {
                    Label(String(localized: "Quiz"), systemImage: "questionmark.circle.fill")
                }

            FAQView()
                .tabItem {
                    Label(String(localized: "FAQ"), systemImage: "list.bullet.rectangle")
                }

            ProgressView()
                .tabItem {
                    Label(String(localized: "Progress"), systemImage: "chart.bar.fill")
                }

            ProfileView()
                .tabItem {
                    Label(String(localized: "Profile"), systemImage: "person.fill")
                }
        }
        .tint(CourtIQTheme.accent)
    }
}
