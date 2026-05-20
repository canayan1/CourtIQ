import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        TabView {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label(lang.t("tab.today"), systemImage: "sun.max.fill")
            }

            NavigationStack {
                PracticeView()
            }
            .tabItem {
                Label(lang.t("tab.practice"), systemImage: "book.closed.fill")
            }

            NavigationStack {
                CommunityFeedView()
            }
            .tabItem {
                Label(lang.t("tab.community"), systemImage: "bubble.left.and.bubble.right.fill")
            }

            NavigationStack {
                TrainingHubView()
            }
            .tabItem {
                Label(lang.t("tab.training"), systemImage: "figure.strengthtraining.traditional")
            }

            NavigationStack {
                MatchesListView()
            }
            .tabItem {
                Label(lang.t("tab.matches"), systemImage: "pencil.and.list.clipboard")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label(lang.t("tab.profile"), systemImage: "person.crop.circle.fill")
            }
        }
        .tint(AppPalette.clay)
        .id(lang.language)
    }
}
