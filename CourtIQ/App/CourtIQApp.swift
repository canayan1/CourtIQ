import SwiftUI

@main
struct CourtIQApp: App {
    @StateObject private var session = UserSessionManager.shared
    @StateObject private var dailyQuizManager = DailyQuizManager.shared
    @StateObject private var trainingProgress = TrainingProgressManager.shared
    @StateObject private var discussionStore = DiscussionStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(dailyQuizManager)
                .environmentObject(trainingProgress)
                .environmentObject(discussionStore)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var session: UserSessionManager

    var body: some View {
        if session.hasCompletedOnboarding {
            MainTabView()
                .alert("Account issue", isPresented: Binding(get: {
                    session.authErrorMessage != nil
                }, set: { newValue in
                    if !newValue {
                        session.authErrorMessage = nil
                    }
                })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(session.authErrorMessage ?? "")
                }
        } else {
            OnboardingView()
                .alert("Account issue", isPresented: Binding(get: {
                    session.authErrorMessage != nil
                }, set: { newValue in
                    if !newValue {
                        session.authErrorMessage = nil
                    }
                })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(session.authErrorMessage ?? "")
                }
        }
    }
}
