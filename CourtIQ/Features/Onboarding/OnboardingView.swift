import SwiftUI
import AuthenticationServices

// MARK: - OnboardingView (Container)

struct OnboardingView: View {
    @EnvironmentObject private var session: UserSessionManager
    @State private var step = 0
    @State private var showPaywall = false

    var body: some View {
        ZStack(alignment: .top) {
            stepContent
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)   // forces SwiftUI to rebuild & animate on step change
        }
        .animation(.easeInOut(duration: 0.30), value: step)
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Onboarding")
                    .environmentObject(session)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: WelcomeStep(onNext: advance)
        case 1: FeaturesStep(onNext: advance)
        case 2: PremiumStep(onNext: advance, showPaywall: $showPaywall)
        default: AccountStep()
        }
    }

    private func advance() {
        step = min(step + 1, 3)
    }
}

// MARK: - Step 0 · Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ZStack {
            // Full-screen hero gradient
            AppPalette.heroGradient
                .ignoresSafeArea()

            // Subtle court lines in background
            TennisCourtLinesView()
                .foregroundStyle(Color.white)
                .opacity(0.07)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Badge
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 160, height: 160)
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        .frame(width: 160, height: 160)
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(Color.white)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }

                Spacer().frame(height: 40)

                // App name
                Text("CourtIQ")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer().frame(height: 12)

                // Tagline
                Text(lang.t("onboarding.tagline"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer().frame(height: 16)

                // Sub-tagline
                Text(lang.t("onboarding.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // CTA
                Button(action: onNext) {
                    Text(lang.t("onboarding.get_started"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.clay)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 48)
            }
        }
    }
}

// MARK: - Step 1 · Features

private struct FeaturesStep: View {
    let onNext: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    private var features: [FeatureRow] {
        [
            FeatureRow(
                icon: "brain.head.profile",
                color: AppPalette.clay,
                title: lang.t("onboarding.daily_iq"),
                body: lang.t("onboarding.daily_iq_desc")
            ),
            FeatureRow(
                icon: "lightbulb.fill",
                color: Color(red: 0.85, green: 0.62, blue: 0.10),
                title: lang.t("onboarding.tip"),
                body: lang.t("onboarding.tip_desc")
            ),
            FeatureRow(
                icon: "figure.strengthtraining.traditional",
                color: AppPalette.moss,
                title: lang.t("onboarding.training"),
                body: lang.t("onboarding.training_desc")
            ),
            FeatureRow(
                icon: "figure.cooldown",
                color: Color(red: 0.30, green: 0.55, blue: 0.80),
                title: lang.t("onboarding.mobility"),
                body: lang.t("onboarding.mobility_desc")
            )
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            OnboardingProgressBar(current: 1, total: 4)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lang.t("onboarding.everything"))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(lang.t("onboarding.everything_desc"))
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                    .padding(.top, 8)

                    // Feature cards
                    VStack(spacing: 14) {
                        ForEach(features) { feature in
                            FeatureCard(feature: feature)
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100) // room for button
            }

            // Sticky bottom button
            VStack(spacing: 0) {
                Divider().opacity(0.3)
                Button(action: onNext) {
                    Text(lang.t("common.next"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(AppPalette.cream)
        }
        .background(AppPalette.cream)
    }
}

private struct FeatureRow: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let body: String
}

private struct FeatureCard: View {
    let feature: FeatureRow

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(feature.color.opacity(0.13))
                    .frame(width: 50, height: 50)
                Image(systemName: feature.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(feature.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)
                Text(feature.body)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Step 2 · Premium

private struct PremiumStep: View {
    let onNext: () -> Void
    @Binding var showPaywall: Bool
    @State private var selectedPlan: PlanOption = .annual
    @EnvironmentObject private var lang: LanguageManager

    enum PlanOption { case monthly, annual }

    private var benefits: [(icon: String, text: String)] {
        [
            ("infinity",                      lang.t("onboarding.feature_quizzes")),
            ("archivebox.fill",               lang.t("onboarding.feature_archive")),
            ("figure.strengthtraining.traditional", lang.t("onboarding.feature_training")),
            ("figure.cooldown",               lang.t("onboarding.feature_mobility")),
            ("clock.badge.checkmark.fill",    lang.t("onboarding.feature_updates")),
            ("star.leadinghalf.filled",       lang.t("onboarding.feature_early")),
            ("chart.line.uptrend.xyaxis",     lang.t("onboarding.feature_history")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(current: 2, total: 4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 10) {
                        // Trial badge
                        Label(lang.t("onboarding.free_trial"), systemImage: "gift.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.moss)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppPalette.moss.opacity(0.12))
                            .clipShape(Capsule())

                        Text(lang.t("onboarding.go_all_access"))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text(lang.t("onboarding.free_week"))
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // Plan toggle
                    VStack(spacing: 10) {
                        PlanCard(
                            title: lang.t("onboarding.annual"),
                            price: "$29",
                            period: lang.t("onboarding.per_year"),
                            detail: lang.t("onboarding.annual_equiv"),
                            badge: lang.t("onboarding.best_value"),
                            isSelected: selectedPlan == .annual,
                            onTap: { selectedPlan = .annual }
                        )
                        PlanCard(
                            title: lang.t("onboarding.monthly"),
                            price: "$5",
                            period: lang.t("onboarding.per_month"),
                            detail: lang.t("onboarding.billed_monthly"),
                            badge: nil,
                            isSelected: selectedPlan == .monthly,
                            onTap: { selectedPlan = .monthly }
                        )
                    }

                    // Benefits
                    VStack(alignment: .leading, spacing: 0) {
                        Text(lang.t("onboarding.whats_included"))
                            .font(.headline)
                            .padding(.bottom, 14)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(benefits, id: \.text) { item in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(AppPalette.clay)
                                        .frame(width: 22)
                                    Text(item.text)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(AppPalette.sand, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    // Early access callout
                    HStack(spacing: 14) {
                        Image(systemName: "bolt.fill")
                            .font(.title3)
                            .foregroundStyle(AppPalette.clay)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(lang.t("onboarding.first_in_line"))
                                .font(.subheadline.weight(.semibold))
                            Text(lang.t("onboarding.first_in_line_desc"))
                                .font(.caption)
                                .foregroundStyle(AppPalette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .background(AppPalette.clay.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(AppPalette.clay.opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            }

            // Sticky bottom
            VStack(spacing: 10) {
                Divider().opacity(0.3)
                VStack(spacing: 10) {
                    Button {
                        showPaywall = true
                    } label: {
                        Text(lang.t("onboarding.start_trial"))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onNext) {
                        Text(lang.t("onboarding.continue_free"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .background(AppPalette.cream)
        }
        .background(AppPalette.cream)
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let detail: String
    let badge: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(AppPalette.clay)
                            .frame(width: 13, height: 13)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(AppPalette.clay.opacity(0.12))
                                .foregroundStyle(AppPalette.clay)
                                .clipShape(Capsule())
                        }
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                }

                Spacer()

                // Price
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(price)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(period)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }
            .padding(16)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppPalette.clay : AppPalette.sand,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Step 3 · Account

private struct AccountStep: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(current: 3, total: 4)

            Spacer()

            VStack(spacing: 32) {
                // Icon
                ZStack {
                    Circle()
                        .fill(AppPalette.clay.opacity(0.12))
                        .frame(width: 110, height: 110)
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(AppPalette.clay)
                }

                // Text
                VStack(spacing: 10) {
                    Text(lang.t("onboarding.one_last_step"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text(lang.t("onboarding.sign_in_desc"))
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                // Sign in buttons
                VStack(spacing: 14) {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        session.handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)

                    Button {
                        session.signInAsGuest()
                    } label: {
                        Text(lang.t("onboarding.guest"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 28)

                // Disclaimer
                Text(lang.t("onboarding.guest_desc"))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .background(AppPalette.cream)
    }
}

// MARK: - Shared: Progress Bar

private struct OnboardingProgressBar: View {
    let current: Int  // 0-based index of current step (0 = step 1)
    let total: Int

    private var progress: Double {
        Double(current + 1) / Double(total)
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppPalette.sand)
                    Rectangle()
                        .fill(AppPalette.clay)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.35), value: progress)
                }
            }
            .frame(height: 3)
        }
    }
}
