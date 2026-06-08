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

    init() {
        CrashReporter.shared.start()
        Task { @MainActor in Haptics.warmUp() }

        // App Store preview / UI-test only: populate sample matches + quiz
        // history so Matches and the trend dashboard render fully. Gated on a
        // launch argument that only the preview UI test passes — never runs in
        // normal use. (Not #if DEBUG because this project's Debug config does
        // not define the DEBUG compilation condition.)
        if ProcessInfo.processInfo.arguments.contains("-seedPreviewData") {
            Task { @MainActor in Self.seedPreviewData() }
        }

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

    /// Inserts a realistic set of logged matches (gently improving ratings →
    /// a clean upward trend) + a few quiz completions, so the App Store
    /// preview shows populated Matches + a non-empty trend dashboard.
    /// Deterministic ids make re-runs idempotent; guarded so it only seeds an
    /// empty store. Reached only via the `-seedPreviewData` launch argument.
    @MainActor
    static func seedPreviewData() {
        // Skip onboarding + health gate so the preview opens in the main app.
        UserSessionManager.shared.debugMarkOnboarded()
        HealthAcknowledgment.recordAcceptance()

        let mm = MatchEntryManager.shared
        guard mm.entries.isEmpty else { return }
        let cal = Calendar.current
        let now = Date()
        // (dayOffset, serve, return, movement, mental, result, opponent, surface, score)
        let rows: [(Int, Int, Int, Int, Int, MatchResult, String, MatchSurface, String)] = [
            (-35, 2, 2, 2, 2, .lost, "Alex",   .hard,  "4-6, 3-6"),
            (-28, 2, 3, 3, 2, .lost, "Jordan", .clay,  "5-7, 4-6"),
            (-21, 3, 3, 3, 3, .won,  "Casey",  .hard,  "6-4, 4-6, 7-5"),
            (-14, 3, 4, 4, 3, .won,  "Morgan", .grass, "6-3, 6-4"),
            (-8,  4, 4, 4, 4, .won,  "Taylor", .hard,  "6-4, 6-4"),
            (-3,  4, 5, 5, 5, .won,  "Sam",    .clay,  "6-2, 6-3"),
            (-1,  5, 5, 5, 5, .won,  "Riley",  .hard,  "6-4, 6-2"),
        ]
        for (i, r) in rows.enumerated() {
            let date = cal.date(byAdding: .day, value: r.0, to: now) ?? now
            mm.save(MatchEntry(
                id: "preview-match-\(i)",
                date: date,
                opponentName: r.6,
                surface: r.7,
                result: r.5,
                score: r.8,
                serveRating: r.1,
                returnRating: r.2,
                movementRating: r.3,
                mentalRating: r.4,
                postMatchNotes: "Stayed patient and moved well.",
                takeaway: "Depth and patience won the big points",
                isQuickLog: i % 2 == 0,
                isDraft: false
            ))
        }
        let dq = DailyQuizManager.shared
        let quizzes: [(String, String, String, Int, Int, [String])] = [
            ("preview-quiz-0", "Serve Patterns",   "Serve",  4, 5, ["forcing the second serve"]),
            ("preview-quiz-1", "Return Depth",     "Return", 3, 5, ["floating the return"]),
            ("preview-quiz-2", "Rally Tolerance",  "Rally",  5, 5, []),
        ]
        for q in quizzes {
            dq.recordCompletion(
                summary: QuizCompletionSummary(
                    quizID: q.0, title: q.1, focusLabel: q.2,
                    score: q.3, totalQuestions: q.4, mistakeTypes: q.5, tacticalBuckets: nil
                ),
                isDaily: true
            )
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
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager

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
    }
}
