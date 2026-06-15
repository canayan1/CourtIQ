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

            VStack(alignment: .leading, spacing: 6) {
                Text(lang.t("home.analyze_title"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lang.t("home.analyze_caption"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 8)

            heroRing
        }
        .padding(20)
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
                        title: lang.t("home.tile_matches")) {
                Haptics.tap()
                tabRouter.selection = .matches
            }
            .reveal(appeared: appeared, index: 2, reduceMotion: reduceMotion)

            FeatureTile(sfSymbol: "bubble.left.and.text.bubble.right.fill",
                        title: lang.t("home.tile_coach")) {
                Haptics.tap()
                tabRouter.selection = .coach
            }
            .reveal(appeared: appeared, index: 3, reduceMotion: reduceMotion)

            FeatureTile(sfSymbol: "person.2.fill",
                        title: lang.t("home.tile_doubles")) {
                Haptics.tap()
                tabRouter.selection = .doubles
            }
            .reveal(appeared: appeared, index: 4, reduceMotion: reduceMotion)

            FeatureTile(sfSymbol: "scope",
                        title: lang.t("home.tile_drill")) {
                Haptics.tap()
                showDrill = true
            }
            .reveal(appeared: appeared, index: 5, reduceMotion: reduceMotion)
        }
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
