import SwiftUI

/// Routes tab selection so the Home tiles can SWITCH tabs (Matches / Coach /
/// Doubles) rather than push a duplicate of those screens inside the Home
/// NavigationStack.
final class TabRouter: ObservableObject {
    enum Tab: Hashable { case home, train, matches, doubles, coach }
    @Published var selection: Tab = .home
}

struct MainTabView: View {
    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var tabRouter = TabRouter()

    // 5 tabs only — iOS pushes a 6th into a "More" overflow that buries it.
    // Phase 1 IA redesign + action-first Home:
    //   1. Home    — action-first landing (flagship swing hero + 2×2 grid).
    //                Profile ("Me") lives behind the avatar button in the
    //                Home header, NOT a tab.
    //   2. Train   — the improve hub.
    //   3. Matches — the post-pivot centerpiece.
    //   4. Doubles — the doubles compatibility surface.
    //   5. Coach   — the AI Coach.
    var body: some View {
        TabView(selection: $tabRouter.selection) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(lang.t("tab.home"), systemImage: "house.fill")
            }
            .tag(TabRouter.Tab.home)

            NavigationStack {
                TrainView()
            }
            .tabItem {
                Label(lang.t("tab.train"), systemImage: "figure.strengthtraining.traditional")
            }
            .tag(TabRouter.Tab.train)

            NavigationStack {
                MatchesListView()
            }
            .tabItem {
                Label(lang.t("tab.matches"), systemImage: "pencil.and.list.clipboard")
            }
            .tag(TabRouter.Tab.matches)

            NavigationStack {
                DoublesView()
            }
            .tabItem {
                Label(lang.t("tab.doubles"), systemImage: "person.2.fill")
            }
            .tag(TabRouter.Tab.doubles)

            NavigationStack {
                AICoachTabRoot()
            }
            .tabItem {
                Label(lang.t("tab.coach"), systemImage: "sparkles")
            }
            .tag(TabRouter.Tab.coach)
        }
        .tint(AppPalette.clay)
        .environmentObject(tabRouter)
        .id(lang.language)
    }
}
