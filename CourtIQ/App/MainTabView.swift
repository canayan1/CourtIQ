import SwiftUI

/// Routes tab selection so Home heroes can SWITCH tabs rather than push a
/// duplicate of those screens inside the Home NavigationStack.
final class TabRouter: ObservableObject {
    enum Tab: Hashable { case home, coach, wall, tactics, journal }
    @Published var selection: Tab = .home
}

struct MainTabView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @StateObject private var tabRouter = TabRouter()

    // The tab bar is the app's map, and the map is what the app sells:
    //   1. Home    — today: the three pillars + shortcuts + recent. Profile
    //                lives behind the avatar button, NOT a tab.
    //   2. Coach   — your video, analysed (AI now, real coach on the waitlist).
    //   3. Wall    — camera-judged wall drills, level by level.
    //   4. Tactics — tactics taught a lesson at a time (Tennis IQ today).
    //   5. Journal — matches and fuel in one calendar you can write into
    //                backwards. The fourth flagship, added when the match log
    //                and the fuel log turned out to be one habit.
    // Doubles, Drills, Recover and Programs are Home shortcuts: they stay,
    // they just stop pretending to be headline features.
    var body: some View {
        TabView(selection: $tabRouter.selection) {
            NavigationStack {
                HomeView().trackScreen("Home")
            }
            .tabItem {
                Label(lang.t("tab.home"), systemImage: "house.fill")
            }
            .tag(TabRouter.Tab.home)

            NavigationStack {
                CoachTabRoot().trackScreen("Coach")
            }
            .tabItem {
                Label(lang.t("tab.coach"), systemImage: "video.fill")
            }
            .tag(TabRouter.Tab.coach)

            NavigationStack {
                WallHubView().trackScreen("Wall")
            }
            .tabItem {
                Label(lang.t("tab.wall"), systemImage: "sportscourt.fill")
            }
            .tag(TabRouter.Tab.wall)

            // No NavigationStack here: the lesson rail owns its own, and its
            // environment must be injected outside it (see TacticsTabRoot).
            TacticsTabRoot().trackScreen("Tactics")
            .tabItem {
                Label(lang.t("tab.tactics"), systemImage: "brain.head.profile")
            }
            .tag(TabRouter.Tab.tactics)

            NavigationStack {
                JournalView().trackScreen("Journal")
            }
            .tabItem {
                Label(lang.t("tab.journal"), systemImage: "book.pages.fill")
            }
            .tag(TabRouter.Tab.journal)
        }
        .tint(AppPalette.clay)
        .environmentObject(tabRouter)
        // The wrist can only reach a phone that is listening — and only a
        // build that has the feature listens. One flag gates every door.
        .task { if SensingFeature.isEnabled { WatchLink.shared.activate() } }
        .id(lang.language)
        #if DEBUG
        // Headless QC: SIMCTL_CHILD_QC_TAB=coach|wall|tactics|journal fronts a tab
        // for screenshot audits without taps.
        .onAppear {
            switch ProcessInfo.processInfo.environment["QC_TAB"] {
            case "coach":   tabRouter.selection = .coach
            case "wall":    tabRouter.selection = .wall
            case "tactics": tabRouter.selection = .tactics
            case "journal": tabRouter.selection = .journal
            default: break
            }
        }
        #endif
    }
}
