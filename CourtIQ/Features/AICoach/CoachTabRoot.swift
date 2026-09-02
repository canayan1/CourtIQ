import SwiftUI

/// Root of the **Coach** tab. The tab is the first thing the app sells: your
/// video, looked at by a coach. Today that coach is the AI swing analysis;
/// the real-coach review is a waitlist card inside it (honest, see
/// `CoachReviewInterestCard`). The AI chat is reached from a finished read
/// ("Ask about this read"), never as a destination of its own.
struct CoachTabRoot: View {
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        SwingAnalysisView(titleOverride: lang.t("tab.coach"))
    }
}
