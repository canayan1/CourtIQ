import SwiftUI

@main
struct CourtIQApp: App {
    @StateObject private var session = UserSessionManager.shared
    @StateObject private var dailyQuizManager = DailyQuizManager.shared
    @StateObject private var trainingProgress = TrainingProgressManager.shared
    @StateObject private var discussionStore = DiscussionStore.shared
    @StateObject private var tipManager = TipManager.shared
    @StateObject private var progressionManager = PlayerProgressionManager.shared
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(dailyQuizManager)
                .environmentObject(trainingProgress)
                .environmentObject(discussionStore)
                .environmentObject(tipManager)
                .environmentObject(progressionManager)
                .environmentObject(languageManager)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        if session.hasCompletedOnboarding {
            MainTabView()
                .alert(lang.t("app.account_issue"), isPresented: Binding(get: {
                    session.authErrorMessage != nil
                }, set: { newValue in
                    if !newValue {
                        session.authErrorMessage = nil
                    }
                })) {
                    Button(lang.t("common.ok"), role: .cancel) {}
                } message: {
                    Text(session.authErrorMessage ?? "")
                }
        } else {
            OnboardingView()
                .alert(lang.t("app.account_issue"), isPresented: Binding(get: {
                    session.authErrorMessage != nil
                }, set: { newValue in
                    if !newValue {
                        session.authErrorMessage = nil
                    }
                })) {
                    Button(lang.t("common.ok"), role: .cancel) {}
                } message: {
                    Text(session.authErrorMessage ?? "")
                }
        }
    }
}
