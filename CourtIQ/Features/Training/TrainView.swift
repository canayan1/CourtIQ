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
    @State private var showProgramsPaywall = false
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
        .sheet(isPresented: $showProgramsPaywall) {
            NavigationStack {
                PaywallView(source: "Programs")
                    .environmentObject(session)
                    .environmentObject(lang)
            }
        }
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
                .font(.system(.title, design: .rounded).weight(.bold))
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
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.85))
                Text(lang.t("train.flagship_swing"))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        // Fixed-height flagship strip: clamp so the icon + two-line title don't
        // overflow the 72pt min-height at the largest accessibility sizes.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .background(AppPalette.swingHeroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Category cards

    private var practiceCard: some View {
        NavigationLink {
            TrainPracticeView()
        } label: {
            LockableTile(sfSymbol: "rectangle.stack",
                         title: lang.t("train.practice"),
                         minHeight: 112)
        }
        .buttonStyle(PressableCardStyle())
    }

    /// Recover links DIRECTLY to the Mobility Library (the old TrainRecoverView
    /// one-row corridor was removed).
    private var recoverCard: some View {
        NavigationLink {
            MobilityLibraryView()
        } label: {
            LockableTile(sfSymbol: "figure.walk",
                         title: lang.t("train.recover"),
                         minHeight: 112)
        }
        .buttonStyle(PressableCardStyle())
    }

    /// Premium-gated: free users get the paywall sheet (no cosmetic-lock
    /// navigation); premium users push the programs list.
    @ViewBuilder
    private var programsCard: some View {
        if session.isPremiumUnlocked {
            NavigationLink {
                TrainProgramsView()
            } label: {
                LockableTile(sfSymbol: "figure.strengthtraining.traditional",
                             title: lang.t("train.programs"),
                             minHeight: 112)
            }
            .buttonStyle(PressableCardStyle())
        } else {
            Button {
                showProgramsPaywall = true
            } label: {
                LockableTile(sfSymbol: "figure.strengthtraining.traditional",
                             title: lang.t("train.programs"),
                             locked: true,
                             minHeight: 112)
            }
            .buttonStyle(PressableCardStyle())
        }
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
