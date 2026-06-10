import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var lang: LanguageManager

    // 5 tabs only — iOS pushes a 6th into a "More" overflow that buries it.
    // Matches is the post-pivot centerpiece so it gets primary placement.
    // v1.0 ships with no user-generated content: the community tip-discussion
    // surface is not exposed in navigation anywhere.
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
                MatchesListView()
            }
            .tabItem {
                Label(lang.t("tab.matches"), systemImage: "pencil.and.list.clipboard")
            }

            NavigationStack {
                TrainingHubView()
            }
            .tabItem {
                Label(lang.t("tab.training"), systemImage: "figure.strengthtraining.traditional")
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
