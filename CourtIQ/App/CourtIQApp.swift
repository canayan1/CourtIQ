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

        // App Store preview / UI-test only: populate sample data so the
        // preview screenshots show populated screens. Launch-arg gated —
        // never runs in normal use.
        if ProcessInfo.processInfo.arguments.contains("-seedPreviewData") {
            Task { @MainActor in Self.seedPreviewData() }
        }

        // Paywall capture only: onboarded + health-acknowledged but NOT
        // premium, so the hard-paywall gate renders the paywall (with the
        // .storekit prices) for the App Store / subscription review screenshot.
        if ProcessInfo.processInfo.arguments.contains("-previewPaywall") {
            Task { @MainActor in
                UserSessionManager.shared.debugMarkOnboarded()
                HealthAcknowledgment.recordAcceptance()
                // Clear any persisted premium (from a prior seeded run) so the
                // hard-paywall gate actually renders the paywall.
                UserSessionManager.shared.subscriptionManager.resetLocalEntitlements()
            }
        }

        // Swing-analysis capture only: onboarded + premium + health-acknowledged
        // so launching lands on the main tabs (no paywall). Reuses the proven
        // seedPreviewData() path (same grant logic as -seedPreviewData) so the
        // app reliably lands on Today. SwingAnalysisView itself starts in the
        // result state showing a sample analysis when this arg is present, so
        // no video/network is needed for the screenshot.
        if ProcessInfo.processInfo.arguments.contains("-previewSwing") {
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

    /// App Store preview / UI-test only (launch-arg gated): completes
    /// onboarding + the health gate and seeds a realistic set of matches,
    /// quiz history, and a Tennis Profile so the preview screenshots show
    /// fully-populated screens. Idempotent.
    @MainActor
    static func seedPreviewData() {
        UserSessionManager.shared.debugMarkOnboarded()
        UserSessionManager.shared.subscriptionManager.debugGrantPremium()
        HealthAcknowledgment.recordAcceptance()

        let mm = MatchEntryManager.shared
        if mm.entries.isEmpty {
            let cal = Calendar.current
            let now = Date()
            let rows: [(Int, Int, Int, Int, Int, MatchResult, String, MatchSurface, String)] = [
                (-35, 2, 2, 2, 2, .lost, "Alex",   .hard,  "4-6, 3-6"),
                (-28, 2, 3, 3, 2, .lost, "Jordan", .clay,  "5-7, 4-6"),
                (-21, 3, 3, 3, 3, .won,  "Casey",  .hard,  "6-4, 4-6, 7-5"),
                (-14, 3, 4, 4, 3, .won,  "Morgan", .grass, "6-3, 6-4"),
                (-8,  4, 4, 4, 4, .won,  "Taylor", .hard,  "6-4, 6-4"),
                (-3,  4, 5, 5, 5, .won,  "Sam",    .clay,  "6-2, 6-3"),
                (-1,  5, 5, 5, 5, .won,  "Riley",  .hard,  "6-4, 6-2"),
            ]
            // The most-recent match (last row) carries a full AI report so the
            // match-detail screenshot shows a finished coaching readout.
            let lastIndex = rows.count - 1
            for (i, r) in rows.enumerated() {
                let date = cal.date(byAdding: .day, value: r.0, to: now) ?? now
                mm.save(MatchEntry(
                    id: "preview-match-\(i)", date: date, opponentName: r.6, surface: r.7,
                    status: .completed, result: r.5, score: r.8,
                    serveRating: r.1, returnRating: r.2,
                    movementRating: r.3, mentalRating: r.4,
                    postMatchNotes: "Stayed patient and moved well.",
                    takeaway: "Depth and patience won the big points",
                    aiReport: i == lastIndex ? Self.previewMatchReport : nil,
                    isDraft: false))
            }
            let dq = DailyQuizManager.shared
            let quizzes: [(String, String, String, Int, Int, [String])] = [
                ("preview-quiz-0", "Serve Patterns",  "Serve",  4, 5, ["forcing the second serve"]),
                ("preview-quiz-1", "Return Depth",    "Return", 3, 5, ["floating the return"]),
                ("preview-quiz-2", "Rally Tolerance", "Rally",  5, 5, []),
            ]
            for q in quizzes {
                dq.recordCompletion(summary: QuizCompletionSummary(
                    quizID: q.0, title: q.1, focusLabel: q.2, score: q.3,
                    totalQuestions: q.4, mistakeTypes: q.5, tacticalBuckets: nil), isDaily: true)
            }
        }

        // Tennis Profile — a solid club aggressive baseliner with serve + net
        // as growth areas, so the preview profile screen reads richly.
        let tps = TennisProfileStore.shared
        if tps.profile == nil {
            let answers = TennisProfileAnswers(
                experience: .threeToTenYears, frequency: .twiceThrice, matchExperience: .leagueMatches,
                levelSelf: .dependableDirected,
                ratings: [.forehand: 4, .backhand: 4, .serve: 2, .ret: 3, .net: 2, .movement: 4],
                pressure: .goForIt, want: .compete)
            var profile = TennisProfile(answers: answers)
            profile.adoptedGoals = profile.result.suggestedGoals
            tps.save(profile)
        }

        // Swing analysis — seed one scored forehand so the Home hero ring shows
        // a real score (82) and the swing history list is populated. No video on
        // disk; the thumbnail loader tolerates the missing file.
        SwingAnalysisStore.shared.debugSeedRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
            date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            stroke: .forehand, handedness: .right, score: 82,
            analysis: previewSwingReport)

        // Doubles — seed one partner + a compatibility report so the Doubles tab
        // shows a partner card with its compatibility score badge.
        let ds = DoublesStore.shared
        if ds.partners.isEmpty {
            let partnerID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
            ds.save(DoublesPartner(
                id: partnerID, name: "Jordan",
                levelRaw: "4", handednessRaw: SwingHandedness.left.rawValue,
                styleRaw: TennisArchetype.aggressiveBaseliner.rawValue,
                strengths: "Big lefty serve, comfortable at net",
                weaknesses: "Backhand under pressure, can over-hit"))
            ds.addReport(DoublesReport(
                partnerId: partnerID, score: 87, reportText: previewDoublesReport))
        }
    }

    /// Sample AI match report for the App Store screenshot harness only.
    private static let previewMatchReport = """
    **The story of the match**
    • You closed out a tight one 6-4, 6-2 by staying disciplined on the big points and making your opponent play one more ball. The serve held up and your movement kept you in neutral rallies long enough to flip them.

    **What carried you**
    • First-serve placement was excellent — you kept pulling them wide and then took the open court.
    • You stayed patient in the long exchanges instead of forcing early, which is exactly the pattern you've been training.

    **One thing to sharpen**
    • Second-serve return court position drifted back a step late in set two. Step in and take it earlier to keep applying pressure.
    """

    /// Sample swing analysis text for the seeded Home hero / history record.
    private static let previewSwingReport = """
    **What's working**
    • Early, complete unit turn — shoulders and hips coil together for clean racquet-head speed.
    • Good balance through the shot; head stays still and eyes track the contact zone.

    **Top fixes**
    • Meet the ball a half-step further out front so you drive through it. Cue: "catch it out front."
    • Finish higher — over the opposite shoulder — to add depth under pressure.
    """

    /// Sample doubles compatibility report for the seeded Doubles partner.
    private static let previewDoublesReport = """
    **Why you click**
    • A righty/lefty pairing covers both alleys naturally and gives you two strong serves into the deuce and ad courts.
    • Your patience plus Jordan's net presence is a classic build-then-finish combination.

    **Plays to run**
    • Use the I-formation on big points to hide Jordan's poach off the lefty serve.
    • When you're returning, look to chip-and-charge behind a low return so Jordan can close.
    """

    var body: some Scene {
        WindowGroup {
            RootView()
                // Lock the app to light mode app-wide. The hardcoded warm
                // AppPalette has no dark variants, so we pin the scheme rather
                // than risk UIKit/system controls (Form/List/.secondary/sheets)
                // rendering dark and mismatching the palette. Belt-and-suspenders
                // alongside UIUserInterfaceStyle=Light in Info.plist.
                .preferredColorScheme(.light)
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
                OnboardingFlowView(onComplete: { session.completeOnboarding() })
            } else if !session.subscriptionManager.entitlementState.isPremium {
                // Hard paywall — no free tier. The app cannot be entered
                // without an active subscription (or trial). This gate
                // re-renders when the entitlement changes, because
                // SubscriptionManager forwards objectWillChange to `session`.
                NavigationStack {
                    PaywallView(source: "Gate", allowsDismiss: false)
                }
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
