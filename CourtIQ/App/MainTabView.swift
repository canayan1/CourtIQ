import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var lang: LanguageManager

    // 5 tabs only — iOS pushes a 6th into a "More" overflow that buries it.
    // Phase 1 IA redesign:
    //   1. Today   — daily orchestrator; Profile ("Me") now lives behind the
    //                avatar button in the Today header, NOT a tab.
    //   2. Train   — the improve hub: merges the old Practice + Training tabs
    //                and absorbs the improvement tools that used to sit on Today.
    //   3. Matches — unchanged, the post-pivot centerpiece.
    //   4. Doubles — the doubles compatibility surface, promoted to a tab.
    //   5. Coach   — the AI Coach, promoted out of Profile into its own tab.
    // No Community tab: v1.0 ships with no user-generated content.
    var body: some View {
        TabView {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label(lang.t("tab.today"), systemImage: "sun.max.fill")
            }

            NavigationStack {
                TrainView()
            }
            .tabItem {
                Label(lang.t("tab.train"), systemImage: "figure.strengthtraining.traditional")
            }

            NavigationStack {
                MatchesListView()
            }
            .tabItem {
                Label(lang.t("tab.matches"), systemImage: "pencil.and.list.clipboard")
            }

            NavigationStack {
                DoublesView()
            }
            .tabItem {
                Label(lang.t("tab.doubles"), systemImage: "person.2.fill")
            }

            NavigationStack {
                AICoachTabRoot()
            }
            .tabItem {
                Label(lang.t("tab.coach"), systemImage: "sparkles")
            }
        }
        .tint(AppPalette.clay)
        .id(lang.language)
    }
}
