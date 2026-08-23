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
    @State private var qcDrills = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // HIG audit A4: the navigation title IS the title — no
                // in-content eyebrow/headline/slogan stack.

                // Design round: the five destinations were an unordered grid.
                // Two eyebrows give the tab a spine — what you do WITH a
                // racquet, and what you do for the body that swings it.
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(lang.t("train.group_court"))
                        .reveal(appeared: appeared, index: 0, reduceMotion: reduceMotion)
                    HStack(spacing: 12) {
                        practiceCard
                            .reveal(appeared: appeared, index: 1, reduceMotion: reduceMotion)
                        swingCard
                            .reveal(appeared: appeared, index: 2, reduceMotion: reduceMotion)
                    }
                    wallCard
                        .reveal(appeared: appeared, index: 3, reduceMotion: reduceMotion)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(lang.t("train.group_body"))
                        .reveal(appeared: appeared, index: 4, reduceMotion: reduceMotion)
                    HStack(spacing: 12) {
                        recoverCard
                            .reveal(appeared: appeared, index: 5, reduceMotion: reduceMotion)
                        programsCard
                            .reveal(appeared: appeared, index: 6, reduceMotion: reduceMotion)
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
        #if DEBUG
        // Headless QC: SIMCTL_CHILD_QC_TRAIN=drills pushes the Drills screen
        // without a tap, mirroring QC_TAB / QC_OPEN elsewhere.
        .navigationDestination(isPresented: $qcDrills) { TrainPracticeView() }
        .onAppear {
            if ProcessInfo.processInfo.environment["QC_TRAIN"] == "drills" { qcDrills = true }
        }
        #endif
        .onAppear {
            if reduceMotion {
                appeared = true
            } else if !appeared {
                withAnimation(Motion.entrance) { appeared = true }
            }
        }
    }

    // MARK: - Swing card (co-equal headliner, was the sole flagship strip)

    private var swingCard: some View {
        NavigationLink {
            SwingAnalysisView()
        } label: {
            LockableTile(sfSymbol: "video.fill",
                         title: lang.t("home.tile_swing"),
                         minHeight: 112,
                         photo: "PhotoForehand")
                .overlay(alignment: .topTrailing) {
                    Text(lang.t("common.beta"))
                        .font(.caption2.weight(.heavy))
                        .kerning(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppPalette.ink.opacity(0.85), in: Capsule())
                        .padding(8)
                        .allowsHitTesting(false)
                }
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityIdentifier("trainSwingAnalysisCard")
    }

    // MARK: - Category cards

    private var practiceCard: some View {
        NavigationLink {
            TrainPracticeView()
        } label: {
            LockableTile(sfSymbol: "scope",
                         title: lang.t("train.drills"),
                         minHeight: 112,
                         photo: "PhotoFootwork")
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
                         minHeight: 112,
                         photo: "PhotoMobility")
        }
        .buttonStyle(PressableCardStyle())
    }

    /// Wall practice — a dedicated solo section (paced drills + free "wall
    /// tennis" rally). Full width below the grid: the user flagged it as a
    /// priority and it will host the premium coached-drill loop later.
    private var wallCard: some View {
        NavigationLink {
            WallHubView()
        } label: {
            LockableTile(sfSymbol: "sportscourt.fill",
                         title: lang.t("train.wall"),
                         minHeight: 96,
                         photo: "PhotoWall")
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityIdentifier("trainWallCard")
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
                             minHeight: 112,
                             photo: "PhotoTraining")
            }
            .buttonStyle(PressableCardStyle())
        } else {
            Button {
                showProgramsPaywall = true
            } label: {
                LockableTile(sfSymbol: "figure.strengthtraining.traditional",
                             title: lang.t("train.programs"),
                             locked: true,
                             minHeight: 112,
                             photo: "PhotoTraining")
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
