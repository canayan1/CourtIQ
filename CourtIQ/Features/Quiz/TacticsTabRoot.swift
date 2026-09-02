import SwiftUI

/// Root of the **Tactics** tab — the third thing the app sells: tactics
/// taught a lesson at a time, Duolingo-style (ported from TennisTactics).
/// The Tennis IQ scenarios live inside it as a card on the rail.
///
/// Owns the lesson stores and injects them here, OUTSIDE `LearnPathView`'s
/// own NavigationStack — a pushed destination does not inherit environment
/// values set inside the stack's root content, and `DialogueView` traps
/// without them. So this tab is NOT wrapped in a NavigationStack by
/// MainTabView; the rail brings its own.
struct TacticsTabRoot: View {
    @EnvironmentObject private var session: UserSessionManager
    @State private var content = ContentStore()
    @State private var progress = PlayerProgress()
    @State private var access = TacticsAccess()

    private var isPremium: Bool { PremiumGate.isPremium(session) }

    var body: some View {
        LearnPathView()
            .environment(content)
            .environment(progress)
            .environment(access)
            .onAppear { access.isSubscribed = isPremium }
            .onChange(of: isPremium) { _, now in access.isSubscribed = now }
            .task { Sound.prepare() }
    }
}
