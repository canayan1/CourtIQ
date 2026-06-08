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
    @StateObject private var matchEntryManager = MatchEntryManager.shared
    @StateObject private var drillManager = CourtTapDrillManager.shared
    @StateObject private var avatarManager = AvatarManager.shared
    @StateObject private var proShotManager = ProShotPatternsManager.shared
    @StateObject private var doublesLink = DoublesLinkRouter.shared

    init() {
        CrashReporter.shared.start()
        Task { @MainActor in Haptics.warmUp() }

        // If the user previously authorized notifications, make sure the
        // daily reminder is re-scheduled (handles app upgrades / device
        // migrations where pending requests can be cleared).
        Task { @MainActor in
            await NotificationManager.shared.refreshAuthorizationStatus()
            if NotificationManager.shared.authorizationStatus == .authorized,
               NotificationManager.shared.dailyReminderEnabled {
                NotificationManager.shared.scheduleDailyReminder()
            }
        }
    }

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
                .environmentObject(matchEntryManager)
                .environmentObject(drillManager)
                .environmentObject(avatarManager)
                .environmentObject(proShotManager)
                .environmentObject(doublesLink)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var doublesLink: DoublesLinkRouter

    // Observe the health-acknowledgment version directly from UserDefaults
    // via @AppStorage so SwiftUI re-renders the moment HealthAcknowledgment
    // .recordAcceptance() writes the new version. The earlier `@State`
    // trick relied on SwiftUI re-evaluating a static read on body, which
    // wasn't reliably tearing down HealthAcknowledgmentView when the
    // user tapped accept — leaving them stuck on the disclaimer screen.
    @AppStorage("CourtIQ.healthAck.version") private var healthAckVersion: Int = 0

    @ViewBuilder
    var body: some View {
        Group {
            if !session.hasCompletedOnboarding {
                OnboardingView()
            } else if healthAckVersion < HealthAcknowledgment.currentVersion {
                // Block access to training/mobility/quiz content until the
                // user explicitly accepts the assumption-of-risk language.
                NavigationStack {
                    HealthAcknowledgmentView(onAccept: { /* AppStorage drives the re-render */ })
                }
            } else {
                MainTabView()
            }
        }
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
        // Doubles invite universal links: https://<host>/d/<CODE>
        .onOpenURL { doublesLink.handle($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { doublesLink.handle(url) }
        }
        .sheet(item: $doublesLink.pendingInvite) { invite in
            NavigationStack {
                DoublesJoinView(prefillCode: invite.code)
            }
            .environmentObject(lang)
            .environmentObject(session)
        }
    }
}
