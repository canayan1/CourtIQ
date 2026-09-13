import SwiftUI

/// Home = today's three moves. One card per pillar (Coach, Wall, Tactics),
/// each showing STATE — your last read, your next rung, your next lesson —
/// not a slogan; a Tennis IQ strip; a single row of "also" chips for the
/// secondary features; a unified Recent feed. One accent (clay), tactile
/// staggered entrance. Profile ("Me") lives behind the header avatar.
struct HomeView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var lang: LanguageManager
    @ObservedObject private var reviewManager = CoachReviewManager.shared
    @EnvironmentObject private var drillManager: CourtTapDrillManager
    @EnvironmentObject private var avatarManager: AvatarManager
    @EnvironmentObject private var matchManager: MatchEntryManager
    @EnvironmentObject private var progressionManager: PlayerProgressionManager
    @EnvironmentObject private var tabRouter: TabRouter

    @ObservedObject private var swingStore = SwingAnalysisStore.shared
    @ObservedObject private var doublesStore = DoublesStore.shared
    @ObservedObject private var iqManager = TennisIQManager.shared
    @ObservedObject private var wallProgress = WallProgressManager.shared
    /// Tactics keeps its own stores (ported). Re-created on appear so a
    /// lesson finished in the Tactics tab shows here when you come back.
    @State private var tacticsProgress = PlayerProgress()
    @State private var tacticsContent = ContentStore()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var showProfile = false
    @State private var showProgramsPaywall = false
    @State private var heroBounce = false

    /// Grid push destinations. Driven by Button + navigationDestination(item:)
    /// rather than NavigationLink INSIDE the LazyVGrid — a NavigationLink mixed
    /// with Buttons in a lazy grid mis-routes taps between cells (IQ opening
    /// Doubles, dead Matches/Doubles).
    /// All grid tiles push their destination via this single route +
    /// navigationDestination. (Switching tabs via tabRouter from a grid tile did
    /// not work; pushing via route does.) The Coach hero still switches tabs.
    private enum Route: Hashable { case swing, tennisIQ, matches, doubles, drills, recover, programs
        #if DEBUG
        /// QC only: the paid coach-review order screen (App Store review
        /// screenshot for the consumable IAP).
        case coachOrder
        #endif
    }
    @State private var route: Route?

    /// The unified Recent feed: the most recent activities across swing, match,
    /// doubles, drill, and quiz, merged newest-first and capped at 8.
    private var recentActivity: [RecentActivity] {
        RecentActivityFeed.build(
            swingStore: swingStore,
            matchManager: matchManager,
            doublesStore: doublesStore,
            drillManager: drillManager,
            quizManager: dailyQuizManager
        )
    }

    /// The UNIFIED daily-activity streak — ANY day with a quiz, a logged match,
    /// a drill, or a wall session counts (not just quizzes), so the number is
    /// honest for every kind of player.
    private var streakDays: Int { ActivityManager.shared.currentStreak }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // The three things the app sells, in the order the tab bar
                // lists them. Each is a tab, so each SWITCHES tabs.
                VStack(spacing: 12) {
                    pillarCard(.coach, icon: "video.fill", photo: "PhotoCoach",
                               eyebrow: lang.t("home.pillar_coach"),
                               title: lang.t("home.coach_hero_title"),
                               state: coachState)
                        .reveal(appeared: appeared, index: 0, reduceMotion: reduceMotion)
                    pillarCard(.wall, icon: "sportscourt.fill", photo: "PhotoWall",
                               eyebrow: lang.t("home.pillar_wall"),
                               title: lang.t("home.pillar_wall_title"),
                               state: wallState)
                        .reveal(appeared: appeared, index: 1, reduceMotion: reduceMotion)
                    pillarCard(.tactics, icon: "brain.head.profile", photo: "PhotoMatch",
                               eyebrow: lang.t("home.pillar_tactics"),
                               title: lang.t("home.pillar_tactics_title"),
                               state: tacticsState)
                        .reveal(appeared: appeared, index: 2, reduceMotion: reduceMotion)
                }

                iqStrip
                    .reveal(appeared: appeared, index: 3, reduceMotion: reduceMotion)

                // Secondary features: chips, not photo tiles, so they never
                // compete with the pillars for the eye.
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(lang.t("home.also"))
                    alsoRow
                }
                .reveal(appeared: appeared, index: 4, reduceMotion: reduceMotion)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Eyebrow(lang.t("home.recent"))
                        Spacer()
                        if streakDays > 0 {
                            Label("\(streakDays)", systemImage: "flame.fill")
                                .font(.system(.footnote, design: .rounded).weight(.bold))
                                .foregroundStyle(AppPalette.clay)
                                .labelStyle(.titleAndIcon)
                                .accessibilityLabel(String(format: lang.t("home.streak_days"), streakDays))
                        }
                    }
                    .reveal(appeared: appeared, index: 5, reduceMotion: reduceMotion)

                    RecentActivityStrip(activities: recentActivity, lang: lang)
                        .reveal(appeared: appeared, index: 6, reduceMotion: reduceMotion)
                }
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        #if DEBUG
        // Headless QC: SIMCTL_CHILD_QC_OPEN=iq|swing auto-pushes that flow.
        .onAppear {
            switch ProcessInfo.processInfo.environment["QC_OPEN"] {
            case "iq":    route = .tennisIQ
            case "swing": route = .swing
            case "coachorder": route = .coachOrder
            case "paywall": showProgramsPaywall = true
            case "profile": showProfile = true
            default:      break
            }
        }
        #endif
        .navigationDestination(item: $route) { dest in
            switch dest {
            case .swing:
                SwingAnalysisView()
            case .tennisIQ:
                // The Daily IQ loop (placement → session → IQ summary). It
                // records through DailyQuizManager itself, so Profile stats and
                // the unified streak keep working unchanged.
                DailyIQView()
            case .matches:
                MatchesListView()
            case .doubles:
                DoublesView()
            case .drills:
                TrainPracticeView()
            case .recover:
                MobilityLibraryView()
            case .programs:
                TrainProgramsView()
            #if DEBUG
            case .coachOrder:
                CoachReviewOrderView(
                    videoURL: URL(fileURLWithPath: "/dev/null"),
                    stroke: .forehand,
                    handedness: .right,
                    ensureSession: { try await session.ensureSessionWithRetry() }
                )
            #endif
            }
        }
        // Header pinned ABOVE the scroll content as its own layer so the hero's
        // tap region can never capture taps meant for the profile button.
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 10)
                .background(AppPalette.cream)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            tacticsProgress = PlayerProgress()
            if reduceMotion {
                appeared = true
            } else if !appeared {
                withAnimation(Motion.entrance) { appeared = true }
                heroBounce = true
            }
        }
        .sheet(isPresented: $showProgramsPaywall) {
            NavigationStack {
                PaywallView(source: "Programs")
                    .environmentObject(session)
                    .environmentObject(lang)
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .environmentObject(session)
                    .environmentObject(dailyQuizManager)
                    .environmentObject(progressionManager)
                    .environmentObject(lang)
                    .environmentObject(avatarManager)
                    .environmentObject(drillManager)
                    .environmentObject(matchManager)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("DropVolley")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppPalette.ink)

            Spacer()

            Button {
                Haptics.tap()
                showProfile = true
            } label: {
                Image(systemName: "figure.tennis")
                    .appFont(19, weight: .semibold, design: .default)
                    .foregroundStyle(AppPalette.clay)
                    .frame(width: 40, height: 40)
                    .background(AppPalette.parchment, in: Circle())
                    .overlay(Circle().stroke(AppPalette.sand, lineWidth: 1))
            }
            .accessibilityLabel(lang.t("today.profile_a11y"))
        }
    }

    // MARK: - Pillar cards

    private var coachState: String {
        if let order = reviewManager.activeOrder {
            if order.status == .delivered { return lang.t("home.state_review_ready") }
            if order.status.isWaitingOnPlayer { return lang.t("home.state_review_reupload") }
            if let hours = order.hoursRemaining {
                return String(format: lang.t("home.state_review_open"), hours)
            }
        }
        if let last = swingStore.records.first {
            let stroke = last.stroke?.rawValue.capitalized ?? last.strokeRaw.capitalized
            if let score = last.score {
                return String(format: lang.t("home.state_last_read"), stroke, score)
            }
            return String(format: lang.t("home.state_last_read_unscored"), stroke)
        }
        return lang.t("home.coach_hero_subtitle")
    }

    private var wallState: String {
        if let next = WallDrill.all.first(where: { !wallProgress.isCleared($0.id) }) {
            return String(format: lang.t("home.state_next_rung"), next.localizedTitle(for: lang.language))
        }
        return lang.t("home.state_all_rungs")
    }

    private var tacticsState: String {
        if let next = tacticsContent.nextLesson(for: tacticsProgress) {
            return String(format: lang.t("home.state_next_lesson"), next.lesson.title,
                          tacticsProgress.completedCount, tacticsContent.totalLessonCount)
        }
        return lang.t("home.state_all_lessons")
    }

    private func pillarCard(_ tab: TabRouter.Tab, icon: String, photo: String,
                            eyebrow: String, title: String, state: String) -> some View {
        Button {
            Haptics.tap()
            tabRouter.selection = tab
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(.caption.weight(.heavy))
                        .kerning(1.2)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(state)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .brandedPhoto(photo, scrim: .hero, cornerRadius: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("\(eyebrow). \(title). \(state)")
    }

    // MARK: - Tennis IQ strip

    /// The daily scenarios are tactics practice, so they live under Tactics;
    /// the number still deserves a line on Home because it is the streak.
    private var iqStrip: some View {
        Button {
            Haptics.tap()
            route = .tennisIQ
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t("home.iq_hero_eyebrow"))
                        .font(.caption.weight(.heavy))
                        .kerning(1.2)
                        .foregroundStyle(AppPalette.inkSoft)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(iqManager.iq)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(AppPalette.clay)
                            .contentTransition(.numericText())
                        Text(iqHeroSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: iqManager.completedSessionToday ? "checkmark.circle.fill" : "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppPalette.clay)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.parchment)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("\(lang.t("iq.eyebrow")) \(iqManager.iq). \(iqHeroSubtitle)")
    }

    private var iqHeroSubtitle: String {
        if !iqManager.hasBaseline { return lang.t("home.iq_hero_baseline") }
        if iqManager.completedSessionToday { return lang.t("home.iq_hero_done") }
        return lang.t("home.iq_hero_ready")
    }

    // MARK: - Also (secondary features)

    private var alsoRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(lang.t("train.drills"), icon: "scope") { route = .drills }
                chip(lang.t("home.tile_matches"), icon: "square.and.pencil") { route = .matches }
                chip(lang.t("home.tile_doubles"), icon: "person.2.fill") { route = .doubles }
                chip(lang.t("train.recover"), icon: "figure.walk") { route = .recover }
                chip(lang.t("train.programs"), icon: session.isPremiumUnlocked ? "figure.strengthtraining.traditional" : "lock.fill") {
                    if session.isPremiumUnlocked { route = .programs } else { showProgramsPaywall = true }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func chip(_ title: String, icon: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppPalette.parchment, in: Capsule())
                .overlay(Capsule().stroke(AppPalette.sand, lineWidth: 1))
        }
        .buttonStyle(PressableCardStyle())
    }
}

// MARK: - Recent activity rail

/// The lower-half unified "Recent" band on Home. Shows up to 8 cross-feature
/// activities (swing, match, doubles, drill, quiz) as a horizontal rail that
/// bleeds off the right edge to signal "more". When the user has NO activity at
/// all across every store, it renders a single full-width first-use hint card
/// instead, so the band is never empty.
struct RecentActivityStrip: View {
    let activities: [RecentActivity]
    @ObservedObject var lang: LanguageManager

    var body: some View {
        if activities.isEmpty {
            firstSwingHint
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(activities) { activity in
                        ActivityCard(activity: activity)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 4)
            }
            // Cancel the parent's 20pt horizontal padding so cards can sit a
            // 16pt inset from the screen edge and bleed off the right.
            .padding(.horizontal, -20)
        }
    }

    private var firstSwingHint: some View {
        NavigationLink {
            SwingAnalysisView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "video.badge.plus")
                    .font(.title2)
                    .foregroundStyle(AppPalette.inkSoft)
                Text(lang.t("home.first_swing"))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.ink)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(AppPalette.sand)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }
}

// MARK: - Staggered entrance modifier

private extension View {
    /// Tactile entrance: opacity + a small rise + slight scale, staggered by
    /// index with a bouncy spring. When Reduce Motion is on it is a no-op
    /// (content is shown at rest, with at most a simple fade handled by the
    /// `appeared` flag flipping instantly).
    @ViewBuilder
    func reveal(appeared: Bool, index: Int, reduceMotion: Bool) -> some View {
        if reduceMotion {
            self.opacity(appeared ? 1 : 0)
        } else {
            self
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .scaleEffect(appeared ? 1 : 0.96)
                .animation(Motion.entrance.delay(Double(index) * Motion.stagger),
                           value: appeared)
        }
    }
}
