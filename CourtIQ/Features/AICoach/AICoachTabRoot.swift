import SwiftUI

/// Root of the **Coach** tab (Phase 1 IA redesign). The AI Coach used to be
/// reached from a card inside ProfileView; it is now a first-class tab.
///
/// Access gating is replicated EXACTLY from ProfileView.aiCoachSection:
///   • `aiCoachOpenToAll` (kill-switch to reopen to everyone)
///   • a real premium entitlement (StoreKit purchase)
///   • a dev-allowlisted account (DEBUG builds only — TestFlight dogfooding)
/// When entitled, the same consent-gated AICoachGate/AICoachView flow renders.
/// When not, a clean landing screen offers an Unlock button → PaywallView.
struct AICoachTabRoot: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var matchManager: MatchEntryManager
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager

    @State private var showPaywall = false

    /// AI Coach access — single source of truth in `PremiumGate`.
    private var isPremium: Bool { PremiumGate.canUseAICoach(session) }

    var body: some View {
        Group {
            if isPremium {
                // Same consent-gated flow ProfileView presented.
                AICoachGate()
                    .environmentObject(lang)
                    .environmentObject(AIChatClient.shared)
                    .environmentObject(session)
                    .environmentObject(matchManager)
                    .environmentObject(dailyQuizManager)
                    .environmentObject(drillManager)
            } else {
                landing
            }
        }
        .navigationTitle(lang.t("tab.coach"))
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Coach")
                    .environmentObject(lang)
                    .environmentObject(session)
            }
        }
    }

    private var landing: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "sparkles")
                        .appFont(100, weight: .bold, design: .default)
                        .foregroundStyle(.white.opacity(0.14))
                        .accessibilityHidden(true)
                        .offset(x: 12, y: -6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .allowsHitTesting(false)

                    VStack(alignment: .leading, spacing: 14) {
                        Label(lang.t("coach.landing_kicker"), systemImage: "sparkles")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(.white.opacity(0.92))

                        Text(lang.t("coach.landing_title"))
                            .font(.system(.title, design: .rounded).weight(.heavy))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(lang.t("coach.landing_body"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            showPaywall = true
                        } label: {
                            Text(lang.t("coach.unlock"))
                                .font(.headline)
                                .foregroundStyle(AppPalette.clay)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(.white))
                        }
                        .buttonStyle(PressableCardStyle())
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Duotone photo layered OVER the existing brand gradient
                // (ZStack: gradient then photo), mirroring Home's hero. The
                // sparkles glyph + content stay on top; foreground is white.
                .background(
                    ZStack {
                        LinearGradient(
                            colors: [AppPalette.gold, AppPalette.clay],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        BrandedPhotoBackground(name: "PhotoCoach", scrim: .hero)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding()
        }
        .background(AppPalette.cream)
    }

}
