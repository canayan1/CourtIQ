import SwiftUI

/// Action-first Home. The **AI Coach** is the flagship hero; **Swing** and
/// **Tennis IQ** sit directly below as co-equal surfaces; Matches / Doubles /
/// Drill follow. A unified Recent feed closes the screen. One accent (clay),
/// tactile staggered entrance. Profile ("Me") lives behind the header avatar.
struct HomeView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager
    @EnvironmentObject private var avatarManager: AvatarManager
    @EnvironmentObject private var matchManager: MatchEntryManager
    @EnvironmentObject private var progressionManager: PlayerProgressionManager
    @EnvironmentObject private var tabRouter: TabRouter

    @ObservedObject private var swingStore = SwingAnalysisStore.shared
    @ObservedObject private var doublesStore = DoublesStore.shared
    @ObservedObject private var iqManager = TennisIQManager.shared

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
                iqHero
                    .reveal(appeared: appeared, index: 0, reduceMotion: reduceMotion)

                coachHero
                    .reveal(appeared: appeared, index: 1, reduceMotion: reduceMotion)

                // The tab bar stays the app's map; these are shortcuts to the
                // same places, not a second map. Home carried only two heroes
                // and a thin Recent strip, which left most of the screen empty
                // on a 6.9" phone — the photos give the day somewhere to go.
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(lang.t("home.jump_back_in"))
                        .reveal(appeared: appeared, index: 2, reduceMotion: reduceMotion)
                    shortcutGrid
                        .reveal(appeared: appeared, index: 3, reduceMotion: reduceMotion)
                }

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
                    .reveal(appeared: appeared, index: 4, reduceMotion: reduceMotion)

                    RecentActivityStrip(activities: recentActivity, lang: lang)
                        .reveal(appeared: appeared, index: 5, reduceMotion: reduceMotion)
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

    /// Photo shortcuts to the four places a session actually goes. Buttons +
    /// `route`, never NavigationLink inside the grid — a NavigationLink mixed
    /// with Buttons in a lazy grid mis-routes taps between cells, which is the
    /// bug that emptied this screen in the first place.
    private var shortcutGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                shortcut(.drills,  title: lang.t("train.drills"),      photo: "PhotoFootwork", icon: "scope")
                shortcut(.matches, title: lang.t("home.tile_matches"), photo: "PhotoMatch",    icon: "square.and.pencil")
            }
            HStack(spacing: 12) {
                shortcut(.doubles, title: lang.t("home.tile_doubles"), photo: "PhotoDoubles",  icon: "person.2.fill")
                shortcut(.recover, title: lang.t("train.recover"),     photo: "PhotoMobility", icon: "figure.walk")
            }
            programsShortcut
        }
    }

    /// Programs is premium: free users get the paywall sheet, not a cosmetic
    /// lock that pushes into an empty screen (mirrors the old Train hub).
    private var programsShortcut: some View {
        Button {
            Haptics.tap()
            if session.isPremiumUnlocked { route = .programs } else { showProgramsPaywall = true }
        } label: {
            LockableTile(sfSymbol: "figure.strengthtraining.traditional",
                         title: lang.t("train.programs"),
                         locked: !session.isPremiumUnlocked,
                         minHeight: 96,
                         photo: "PhotoTraining")
        }
        .buttonStyle(PressableCardStyle())
    }

    private func shortcut(_ dest: Route, title: String, photo: String, icon: String) -> some View {
        Button {
            Haptics.tap()
            route = dest
        } label: {
            LockableTile(sfSymbol: icon, title: title, minHeight: 112, photo: photo)
        }
        .buttonStyle(PressableCardStyle())
    }

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

    // MARK: - Flagship hero: Daily Tennis IQ

    /// The daily core loop, above everything: your Tennis IQ number, streak,
    /// and today's 2-minute session (or the one-time baseline placement).
    /// Solid clay so it reads as THE brand moment among the photo cards.
    private var iqHero: some View {
        Button {
            Haptics.tap()
            route = .tennisIQ
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.t("home.iq_hero_eyebrow"))
                        .font(.caption.weight(.heavy))
                        .kerning(1.2)
                        .foregroundStyle(.white.opacity(0.85))
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(iqManager.iq)")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        if streakDays > 0 {
                            Label("\(streakDays)", systemImage: "flame.fill")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(AppPalette.gold)
                        }
                    }
                    Text(iqHeroSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: iqManager.completedSessionToday ? "checkmark.circle.fill" : "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .background(
                LinearGradient(colors: [AppPalette.clay, AppPalette.clayText],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 24)
            )
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

    // MARK: - AI Coach hero

    private var coachHero: some View {
        // Coach is a tab, so the hero switches tabs (Button) rather than pushing.
        Button {
            Haptics.tap()
            tabRouter.selection = .coach
        } label: {
            coachHeroLabel
        }
        .buttonStyle(PressableCardStyle())
    }

    private var coachHeroLabel: some View {
        HStack(spacing: 16) {
            Image(systemName: "video.fill")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: heroBounce)
                .frame(width: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(lang.t("home.coach_hero_title"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lang.t("home.coach_hero_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .brandedPhoto("PhotoCoach", scrim: .hero, cornerRadius: 24)
        .contentShape(Rectangle())
    }

    // MARK: - Full-width link row (Matches / Doubles / Drill)

    private func linkRow(icon: String, title: String, photo: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 28)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandedPhoto(photo, scrim: .bottom, cornerRadius: 22)
            // Make the whole row rect the hit target — the branded photo is a
            // `.background` (doesn't extend the tap area on its own), so without
            // this the tappable region is only the content, not the full card.
            .contentShape(Rectangle())
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
