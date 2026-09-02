import SwiftUI

/// Root of the **Coach** tab. The tab is the first thing the app sells: your
/// video, looked at by a coach. Today that coach is the AI swing analysis;
/// the real-coach review is a waitlist card inside it (honest, see
/// `CoachReviewInterestCard`). So the tab root IS the video flow, with the
/// AI chat one tap away in the toolbar rather than the other way round.
struct CoachTabRoot: View {
    @EnvironmentObject private var lang: LanguageManager
    @State private var showChat = false

    var body: some View {
        SwingAnalysisView(titleOverride: lang.t("tab.coach"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.tap()
                        showChat = true
                    } label: {
                        Label(lang.t("coach.ask_ai"), systemImage: "bubble.left.and.text.bubble.right.fill")
                    }
                    .tint(AppPalette.clay)
                    .accessibilityIdentifier("coachAskAIButton")
                }
            }
            .navigationDestination(isPresented: $showChat) {
                AICoachTabRoot()
            }
            #if DEBUG
            .onAppear {
                if ProcessInfo.processInfo.environment["QC_COACH"] == "chat" { showChat = true }
            }
            #endif
    }
}
