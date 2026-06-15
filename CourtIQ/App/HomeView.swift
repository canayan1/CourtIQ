import SwiftUI

/// Action-first Home ("Home B"): a flagship swing hero + a 2×2 feature grid.
/// Minimal text, ONE accent (clay) on the hero + active states, and a
/// TACTILE + KINETIC entrance (bouncy staggered reveal + a kinetic score ring).
///
/// Supersedes TodayView as the first tab. The old greeting + activity rings
/// moved to Profile ("Me"); this screen is purely about launching the four
/// improvement surfaces, led by the swing analyzer.
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var showProfile = false
    @State private var showDrill = false
    @State private var heroBounce = false
    @Namespace private var ns

    /// Latest swing score (0–100) for the hero ring, if any swing has been
    /// scored. nil → first-use state (a play glyph, no number).
    private var latestSwingScore: Int? {
        swingStore.records.first(where: { $0.score != nil })?.score
    }

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

    /// Current daily streak — sourced the same way Profile reads it.
    private var streakDays: Int { dailyQuizManager.currentStreak }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                heroSection
                    .reveal(appeared: appeared, index: 0, reduceMotion: reduceMotion)

                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(lang.t("home.your_game"))
                        .reveal(appeared: appeared, index: 1, reduceMotion: reduceMotion)

                    grid
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Eyebrow(lang.t("home.recent"))
                        Spacer()
                        if streakDays > 0 {
                            Label("\(streakDays)", systemImage: "flame.fill")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(AppPalette.clay)
                                .labelStyle(.titleAndIcon)
                                .accessibilityLabel(String(format: lang.t("home.streak_days"), streakDays))
                        }
                    }
                    .reveal(appeared: appeared, index: 6, reduceMotion: reduceMotion)

                    RecentActivityStrip(activities: recentActivity, lang: lang)
                        .reveal(appeared: appeared, index: 7, reduceMotion: reduceMotion)
                }
            }
            .padding(20)
        }
        .background(AppPalette.cream)
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
        .fullScreenCover(isPresented: $showDrill) {
            NavigationStack {
                CourtTapDrillView()
                    .environmentObject(lang)
                    .environmentObject(drillManager)
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
                TennisAvatarView(config: avatarManager.config, size: 30)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppPalette.sand, lineWidth: 1))
            }
            .accessibilityLabel(lang.t("today.profile_a11y"))
        }
    }

    // MARK: - Flagship hero

    @ViewBuilder
    private var heroSection: some View {
        if #available(iOS 18, *) {
            NavigationLink {
                SwingAnalysisView()
                    .navigationTransition(.zoom(sourceID: "swing", in: ns))
            } label: {
                heroLabel
            }
            .buttonStyle(PressableCardStyle())
            .matchedTransitionSource(id: "swing", in: ns)
        } else {
            NavigationLink {
                SwingAnalysisView()
            } label: {
                heroLabel
            }
            .buttonStyle(PressableCardStyle())
        }
    }

    private var heroLabel: some View {
        HStack(spacing: 16) {
            Image(systemName: "video.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: heroBounce)
                .frame(width: 56)

            Text(lang.t("home.analyze_title"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            heroRing
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.clay)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var heroRing: some View {
        if let score = latestSwingScore {
            ScoreRing(size: 54, score: score, accent: .white,
                      track: .white.opacity(0.28))
        } else {
            // First-use: no score yet → a play glyph instead of a number.
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.28), lineWidth: 54 * 0.11)
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)
            .accessibilityHidden(true)
        }
    }

    // MARK: - 2×2 feature grid

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10),
                      GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            FeatureTile(sfSymbol: "list.clipboard.fill",
                        title: lang.t("home.tile_matches"),
                        minHeight: 112) {
                Haptics.tap()
                tabRouter.selection = .matches
            }
            .reveal(appeared: appeared, index: 2, reduceMotion: reduceMotion)

            FeatureTile(sfSymbol: "bubble.left.and.text.bubble.right.fill",
                        title: lang.t("home.tile_coach"),
                        minHeight: 112) {
                Haptics.tap()
                tabRouter.selection = .coach
            }
            .reveal(appeared: appeared, index: 3, reduceMotion: reduceMotion)

            FeatureTile(sfSymbol: "person.2.fill",
                        title: lang.t("home.tile_doubles"),
                        minHeight: 112) {
                Haptics.tap()
                tabRouter.selection = .doubles
            }
            .reveal(appeared: appeared, index: 4, reduceMotion: reduceMotion)

            FeatureTile(sfSymbol: "scope",
                        title: lang.t("home.tile_drill"),
                        minHeight: 112) {
                Haptics.tap()
                showDrill = true
            }
            .reveal(appeared: appeared, index: 5, reduceMotion: reduceMotion)
        }
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
