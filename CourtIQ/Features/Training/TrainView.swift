import SwiftUI

/// The "improve" hub (Phase 2 redesign). A compact, sentence-free landing that
/// fits ~one screen: a title block, a Swing flagship strip, and a small grid of
/// category cards that push into dedicated child screens. It RE-HOMES existing
/// destination views — it does not reimplement any of them.
struct TrainView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @Namespace private var ns

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleBlock

                swingFlagship
                    .reveal(appeared: appeared, index: 0, reduceMotion: reduceMotion)

                VStack(spacing: 12) {
                    practiceCard
                        .reveal(appeared: appeared, index: 1, reduceMotion: reduceMotion)

                    HStack(spacing: 12) {
                        recoverCard
                            .reveal(appeared: appeared, index: 2, reduceMotion: reduceMotion)
                        programsCard
                            .reveal(appeared: appeared, index: 3, reduceMotion: reduceMotion)
                    }
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("tab.train"))
        .onAppear {
            if reduceMotion {
                appeared = true
            } else if !appeared {
                withAnimation(Motion.entrance) { appeared = true }
            }
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(lang.t("train.subtitle"))
            Text(lang.t("train.headline"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Swing flagship strip

    @ViewBuilder
    private var swingFlagship: some View {
        if #available(iOS 18, *) {
            NavigationLink {
                SwingAnalysisView()
                    .navigationTransition(.zoom(sourceID: "swingTrain", in: ns))
            } label: {
                swingFlagshipLabel
            }
            .buttonStyle(PressableCardStyle())
            .matchedTransitionSource(id: "swingTrain", in: ns)
            .accessibilityIdentifier("trainSwingAnalysisCard")
        } else {
            NavigationLink {
                SwingAnalysisView()
            } label: {
                swingFlagshipLabel
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityIdentifier("trainSwingAnalysisCard")
        }
    }

    private var swingFlagshipLabel: some View {
        HStack(spacing: 14) {
            Image(systemName: "video.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("train.flagship"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.85))
                Text(lang.t("train.flagship_swing"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(AppPalette.swingHeroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Category cards

    private var practiceCard: some View {
        NavigationLink {
            TrainPracticeView()
        } label: {
            CategoryCard(symbol: "rectangle.stack",
                         title: lang.t("train.practice"))
        }
        .buttonStyle(PressableCardStyle())
    }

    private var recoverCard: some View {
        NavigationLink {
            TrainRecoverView()
        } label: {
            CategoryCard(symbol: "figure.walk",
                         title: lang.t("train.recover"))
        }
        .buttonStyle(PressableCardStyle())
    }

    private var programsCard: some View {
        NavigationLink {
            TrainProgramsView()
        } label: {
            CategoryCard(symbol: "figure.strengthtraining.traditional",
                         title: lang.t("train.programs"),
                         locked: !session.isPremiumUnlocked)
        }
        .buttonStyle(PressableCardStyle())
    }
}

// MARK: - Category card

/// A FeatureTile-recipe card with an SF Symbol + a one/two-word title, plus an
/// optional lock glyph. Sentence-free — the icon + word carry meaning (matching
/// the Home tiles). Used on the Train hub grid.
struct CategoryCard: View {
    let symbol: String
    let title: String
    var locked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppPalette.clay)
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Staggered entrance modifier

private extension View {
    /// Mirrors HomeView's tactile staggered entrance; Reduce-Motion safe.
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
