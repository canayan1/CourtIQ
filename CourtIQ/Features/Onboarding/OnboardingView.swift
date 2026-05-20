import SwiftUI
import AuthenticationServices

// MARK: - OnboardingView (Container)

struct OnboardingView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager

    @State private var step = 0
    @State private var selectedLevel    = ""
    @State private var selectedFocus    = ""
    @State private var selectedFrequency = ""

    var body: some View {
        ZStack {
            stepContent
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
        }
        .animation(.easeInOut(duration: 0.28), value: step)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: WelcomeStep(onNext: advance)
        case 1: LevelStep(selected: $selectedLevel, dotIndex: 0, onBack: goBack, onNext: advance)
        case 2: FocusStep(selected: $selectedFocus, dotIndex: 1, onBack: goBack, onNext: advance)
        case 3: FrequencyStep(selected: $selectedFrequency, dotIndex: 2, onBack: goBack, onNext: advance)
        case 4: PlanRevealStep(level: selectedLevel, focus: selectedFocus, frequency: selectedFrequency, dotIndex: 2, onBack: goBack, onNext: advance)
        case 5: TourStep(dotIndex: 3, onBack: goBack, onNext: advance)
        case 6: PaywallStep(dotIndex: 4, onBack: goBack, onSkip: advance)
        default: AccountStep(dotIndex: 5, onAppleFinish: applyAndSignInApple, onGuestFinish: applyAndSignInGuest)
        }
    }

    private func advance() { step = min(step + 1, 7) }
    private func goBack()  { step = max(step - 1, 0) }

    private func applyOnboardingAnswers() {
        let focusLabel: String
        switch selectedFocus {
        case "decision": focusLabel = "Decision-making"
        case "strokes":  focusLabel = "Stroke mechanics"
        case "mobility": focusLabel = "Mobility & recovery"
        case "mental":   focusLabel = "Mental game"
        default:         focusLabel = "Decision-making"
        }
        if !focusLabel.isEmpty { session.updateCurrentFocus(focusLabel) }
        UserDefaults.standard.set(selectedLevel,     forKey: "CourtIQ.onboardingLevel")
        UserDefaults.standard.set(selectedFrequency, forKey: "CourtIQ.onboardingFrequency")
    }

    private func applyAndSignInApple(_ result: Result<ASAuthorization, Error>) {
        applyOnboardingAnswers()
        session.handleAppleSignIn(result)
    }

    private func applyAndSignInGuest() {
        applyOnboardingAnswers()
        session.signInAsGuest()
    }
}

// MARK: - Shared: Progress Dots

struct OnboardingDots: View {
    let current: Int  // 0-based, out of 5
    let total = 5

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? AppPalette.clay : AppPalette.sand)
                    .frame(width: i == current ? 22 : 7, height: 5)
                    .animation(.easeInOut(duration: 0.22), value: current)
            }
        }
    }
}

// MARK: - Shared: Question top bar

private struct QuestionTopBar: View {
    let dotIndex: Int
    let stepLabel: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                ZStack {
                    Circle()
                        .fill(AppPalette.inkSoft.opacity(0.08))
                        .frame(width: 34, height: 34)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)
                }
            }
            .buttonStyle(.plain)

            OnboardingDots(current: dotIndex)

            Spacer()

            Text(stepLabel)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding(.horizontal, 20)
        .padding(.top, 62)
        .padding(.bottom, 10)
    }
}

// MARK: - Shared: Option card

private struct OnboardingOptionCard: View {
    let isSelected: Bool
    let symbol: OnboardingOptionSymbol
    let title: String
    let desc: String
    let onTap: () -> Void

    enum OnboardingOptionSymbol {
        case letter(String)
        case sf(String)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon area
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? AppPalette.clay.opacity(0.13) : AppPalette.sand.opacity(0.45))
                        .frame(width: 44, height: 44)
                    switch symbol {
                    case .letter(let l):
                        Text(l)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? AppPalette.clay : AppPalette.inkSoft)
                    case .sf(let name):
                        Image(systemName: name)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isSelected ? AppPalette.clay : AppPalette.inkSoft)
                    }
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                // Radio
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(AppPalette.clay)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .background(isSelected ? Color.white : AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: isSelected ? AppPalette.clay.opacity(0.14) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Shared: Bottom CTA bar

private struct OnboardingCTABar: View {
    let label: String
    let enabled: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { if enabled { onTap() } }) {
                HStack(spacing: 6) {
                    Text(label)
                    if enabled {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(enabled ? AppPalette.clay : AppPalette.sand)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 34)
        .background(.thinMaterial)
    }
}

// MARK: - Step 0 · Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ZStack {
            AppPalette.heroGradient.ignoresSafeArea()

            TennisCourtLinesView()
                .foregroundStyle(Color.white.opacity(0.07))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Badge circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        .frame(width: 148, height: 148)
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(Color.white)
                }

                Spacer().frame(height: 44)

                Text("CourtIQ")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Spacer().frame(height: 14)

                Text(lang.t("onb.welcome.tagline"))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer().frame(height: 12)

                // Welcome body removed: badge + tagline + onboarding steps
                // tell the story better than a copy line.

                Spacer()

                VStack(spacing: 14) {
                    Button(action: onNext) {
                        Text(lang.t("onb.welcome.cta"))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(AppPalette.clay)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text(lang.t("onb.welcome.footer"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
    }
}

// MARK: - Step 1 · Level

private struct LevelStep: View {
    @Binding var selected: String
    let dotIndex: Int
    let onBack: () -> Void
    let onNext: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    private var options: [(id: String, letter: String, title: String, desc: String)] {
        [
            ("beginner", "1", lang.t("onb.level.beginner.title"), lang.t("onb.level.beginner.desc")),
            ("club",     "2", lang.t("onb.level.club.title"),     lang.t("onb.level.club.desc")),
            ("advanced", "3", lang.t("onb.level.advanced.title"), lang.t("onb.level.advanced.desc")),
            ("coach",    "4", lang.t("onb.level.coach.title"),    lang.t("onb.level.coach.desc")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            QuestionTopBar(dotIndex: dotIndex, stepLabel: lang.t("onb.level.step"), onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    // Subtitle removed — the title is the question, repetition adds nothing.
                    Text(lang.t("onb.level.title"))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        ForEach(options, id: \.id) { opt in
                            OnboardingOptionCard(
                                isSelected: selected == opt.id,
                                symbol: .letter(opt.letter),
                                title: opt.title,
                                desc: opt.desc,
                                onTap: { selected = opt.id }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 120)
            }

            OnboardingCTABar(label: lang.t("onb.cta.continue"), enabled: !selected.isEmpty, onTap: onNext)
        }
        .background(AppPalette.cream)
    }
}

// MARK: - Step 2 · Focus

private struct FocusStep: View {
    @Binding var selected: String
    let dotIndex: Int
    let onBack: () -> Void
    let onNext: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    private var options: [(id: String, sf: String, title: String, desc: String)] {
        [
            ("decision", "brain.head.profile", lang.t("onb.focus.decision.title"), lang.t("onb.focus.decision.desc")),
            ("strokes",  "tennisball.fill",    lang.t("onb.focus.strokes.title"),  lang.t("onb.focus.strokes.desc")),
            ("mobility", "figure.cooldown",    lang.t("onb.focus.mobility.title"), lang.t("onb.focus.mobility.desc")),
            ("mental",   "flame.fill",         lang.t("onb.focus.mental.title"),   lang.t("onb.focus.mental.desc")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            QuestionTopBar(dotIndex: dotIndex, stepLabel: lang.t("onb.focus.step"), onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    Text(lang.t("onb.focus.title"))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        ForEach(options, id: \.id) { opt in
                            OnboardingOptionCard(
                                isSelected: selected == opt.id,
                                symbol: .sf(opt.sf),
                                title: opt.title,
                                desc: opt.desc,
                                onTap: { selected = opt.id }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 120)
            }

            OnboardingCTABar(label: lang.t("onb.cta.continue"), enabled: !selected.isEmpty, onTap: onNext)
        }
        .background(AppPalette.cream)
    }
}

// MARK: - Step 3 · Frequency

private struct FrequencyStep: View {
    @Binding var selected: String
    let dotIndex: Int
    let onBack: () -> Void
    let onNext: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    private var options: [(id: String, letter: String, title: String, desc: String)] {
        [
            ("1-2", "1", lang.t("onb.freq.1_2.title"),   lang.t("onb.freq.1_2.desc")),
            ("3-4", "2", lang.t("onb.freq.3_4.title"),   lang.t("onb.freq.3_4.desc")),
            ("5+",  "3", lang.t("onb.freq.5plus.title"), lang.t("onb.freq.5plus.desc")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            QuestionTopBar(dotIndex: dotIndex, stepLabel: lang.t("onb.freq.step"), onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    Text(lang.t("onb.freq.title"))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        ForEach(options, id: \.id) { opt in
                            OnboardingOptionCard(
                                isSelected: selected == opt.id,
                                symbol: .letter(opt.letter),
                                title: opt.title,
                                desc: opt.desc,
                                onTap: { selected = opt.id }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 120)
            }

            OnboardingCTABar(label: lang.t("onb.cta.build_plan"), enabled: !selected.isEmpty, onTap: onNext)
        }
        .background(AppPalette.cream)
    }
}

// MARK: - Step 4 · Plan Reveal

private struct PlanRevealStep: View {
    let level: String
    let focus: String
    let frequency: String
    let dotIndex: Int
    let onBack: () -> Void
    let onNext: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    private var iqDesc: String {
        focus == "decision"
            ? lang.t("onb.plan.iq.decision")
            : lang.t("onb.plan.iq.default")
    }

    private var trainingDesc: String {
        switch frequency {
        case "5+":  return lang.t("onb.plan.training.5plus")
        case "1-2": return lang.t("onb.plan.training.1_2")
        default:    return lang.t("onb.plan.training.default")
        }
    }

    private var mobilityDesc: String {
        focus == "mobility"
            ? lang.t("onb.plan.mobility.priority")
            : lang.t("onb.plan.mobility.preview")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar (no step counter — this is the reward screen)
            HStack(spacing: 14) {
                Button(action: onBack) {
                    ZStack {
                        Circle()
                            .fill(AppPalette.inkSoft.opacity(0.08))
                            .frame(width: 34, height: 34)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)
                    }
                }
                .buttonStyle(.plain)
                OnboardingDots(current: dotIndex)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 62)
            .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Tag + title
                    VStack(alignment: .leading, spacing: 10) {
                        Label(lang.t("onb.plan.tag"), systemImage: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppPalette.moss)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppPalette.moss.opacity(0.12))
                            .clipShape(Capsule())

                        Text(lang.t("onb.plan.title"))
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppPalette.ink)
                    }

                    // Plan rows
                    VStack(spacing: 10) {
                        PlanRevealRow(icon: "brain.head.profile", color: AppPalette.clay,
                                      title: lang.t("onb.plan.row.iq"), desc: iqDesc)
                        PlanRevealRow(icon: "figure.strengthtraining.traditional", color: AppPalette.moss,
                                      title: lang.t("onb.plan.row.training"), desc: trainingDesc)
                        PlanRevealRow(icon: "figure.cooldown", color: Color(red: 0.30, green: 0.55, blue: 0.80),
                                      title: lang.t("onb.plan.row.mobility"), desc: mobilityDesc)
                        PlanRevealRow(icon: "lightbulb.fill", color: Color(red: 0.85, green: 0.62, blue: 0.10),
                                      title: lang.t("onb.plan.row.tip"), desc: lang.t("onb.plan.tip.desc"))
                    }

                    // Free forever badge — one line, no body paragraph.
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppPalette.moss)
                            .font(.system(size: 20))
                        Text(lang.t("onb.plan.free_title"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(AppPalette.moss)
                        Spacer()
                    }
                    .padding(16)
                    .background(AppPalette.moss.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppPalette.moss.opacity(0.25), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }

            OnboardingCTABar(label: lang.t("onb.cta.see_included"), enabled: true, onTap: onNext)
        }
        .background(AppPalette.cream)
    }
}

private struct PlanRevealRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.13))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Step 5 · Paywall

private struct PaywallStep: View {
    let dotIndex: Int
    let onBack: () -> Void
    let onSkip: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    private var benefits: [String] {
        [
            lang.t("onb.paywall.b1"),
            lang.t("onb.paywall.b2"),
            lang.t("onb.paywall.b3"),
            lang.t("onb.paywall.b4"),
            lang.t("onb.paywall.b5"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with Skip
            HStack(spacing: 14) {
                Button(action: onBack) {
                    ZStack {
                        Circle()
                            .fill(AppPalette.inkSoft.opacity(0.08))
                            .frame(width: 34, height: 34)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)
                    }
                }
                .buttonStyle(.plain)

                OnboardingDots(current: dotIndex)

                Spacer()

                Button(lang.t("onb.cta.skip"), action: onSkip)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
            }
            .padding(.horizontal, 20)
            .padding(.top, 62)
            .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header — preview, not purchase
                    VStack(alignment: .leading, spacing: 8) {
                        Label(lang.t("onb.paywall.tag"), systemImage: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppPalette.moss)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppPalette.moss.opacity(0.12))
                            .clipShape(Capsule())

                        Text(lang.t("onb.paywall.title"))
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppPalette.ink)
                    }

                    // What's included — header removed; check-row list is
                    // self-evidently a benefits list.
                    VStack(alignment: .leading, spacing: 12) {

                        ForEach(benefits, id: \.self) { benefit in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppPalette.clay)
                                    .frame(width: 18)
                                    .padding(.top, 1)
                                Text(benefit)
                                    .font(.subheadline)
                                    .foregroundStyle(AppPalette.ink)
                            }
                        }
                    }
                    .padding(18)
                    .background(AppPalette.parchment)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 140)
            }

            // Bottom CTA — advances to account step. Real purchase happens
            // later in PaywallView (with prices, legal links, restore button).
            VStack(spacing: 0) {
                Button(action: onSkip) {
                    Text(lang.t("onb.cta.continue"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppPalette.clay)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 34)
            }
            .background(.thinMaterial)
        }
        .background(AppPalette.cream)
    }
}

private struct PaywallPlanCard: View {
    let isSelected: Bool
    let badge: String?
    let title: String
    let detail: String
    let price: String
    let period: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(AppPalette.clay).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(AppPalette.clay.opacity(0.12))
                                .foregroundStyle(AppPalette.clay)
                                .clipShape(Capsule())
                        }
                    }
                    Text(detail).font(.caption).foregroundStyle(AppPalette.inkSoft)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(price).font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(period).font(.caption.weight(.semibold)).foregroundStyle(AppPalette.inkSoft)
                }
            }
            .padding(16)
            .background(isSelected ? Color.white : AppPalette.parchment)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: isSelected ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: isSelected ? AppPalette.clay.opacity(0.12) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Step 6 · Account

private struct AccountStep: View {
    let dotIndex: Int
    let onAppleFinish: (Result<ASAuthorization, Error>) -> Void
    let onGuestFinish: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(spacing: 0) {
            // Top bar — no back button on final step
            HStack {
                OnboardingDots(current: dotIndex)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 62)
            .padding(.bottom, 10)

            Spacer()

            VStack(spacing: 28) {
                // Person icon
                ZStack {
                    Circle()
                        .fill(AppPalette.clay.opacity(0.12))
                        .frame(width: 108, height: 108)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(AppPalette.clay)
                }

                VStack(spacing: 10) {
                    Text(lang.t("onb.account.title"))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .multilineTextAlignment(.center)

                    Text(lang.t("onb.account.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        onAppleFinish(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)

                    Button(action: onGuestFinish) {
                        Text(lang.t("onb.account.guest"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(AppPalette.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(AppPalette.parchment)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppPalette.sand, lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)

                Text(lang.t("onb.account.guest_note"))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Spacer()
        }
        .background(AppPalette.cream)
    }
}
