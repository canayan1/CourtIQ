import SwiftUI

/// First-launch HOOK + FEATURE SHOWCASE that opens the app, BEFORE the Tennis
/// Profile questionnaire. Two pieces, both presented by `OnboardingFlowView`:
///
///  • `OnboardingHookView` — a full-bleed `PhotoHero` `.hero` screen that
///    positions DropVolley as the Tennis IQ trainer (the strategy / decision /
///    technique-coaching side). Confident + specific, no unverifiable "only app
///    in the world" superlative (App Review risk). One "Get started" CTA.
///
///  • `OnboardingShowcaseView` — a paged carousel of 5 feature screens, each a
///    duotone photo hero + a one-line headline + ONE concrete, clearly-labeled
///    SAMPLE rendered like the real output (reuses `ScoreRing`, the paywall
///    sample-card style, `Eyebrow`). Skip + page indicators; staggered reveal
///    that honors Reduce Motion. Both hand control back via callbacks so the
///    flow can bridge straight into the existing questionnaire.
///
/// Visual language mirrors Home/Train: duotone `BrandedPhotoBackground` heroes,
/// white foreground + scrim on photos, parchment/sand sample cards, clay accent.

// MARK: - Hook (opens the app)

struct OnboardingHookView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onStart: () -> Void

    private var copy: OnboardingCopy { OnboardingCopy(lang: lang.language) }

    @State private var revealed = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            BrandedPhotoBackground(name: "PhotoHero", scrim: .hero)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Spacer(minLength: 0)

                Eyebrow(copy.hookEyebrow)
                    .foregroundStyle(.white.opacity(0.85))

                Text(copy.hookTitle)
                    .appFont(40, weight: .heavy)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(copy.hookSubtitle)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Haptics.tap()
                    onStart()
                } label: {
                    Text(copy.getStarted)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)
                .padding(.top, 8)
            }
            .padding(28)
            .padding(.bottom, 8)
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 16)
        }
        .onAppear {
            guard !reduceMotion else { revealed = true; return }
            withAnimation(Motion.entrance) { revealed = true }
        }
    }
}

// MARK: - Feature showcase carousel

struct OnboardingShowcaseView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Advance into the questionnaire bridge. Called by both the per-page
    /// Continue (on the last page) and the Skip button.
    let onFinish: () -> Void

    private var copy: OnboardingCopy { OnboardingCopy(lang: lang.language) }

    @State private var page = 0
    /// Auto-play: the carousel advances by itself like a product demo reel
    /// until the user swipes (taking control) or the last page is reached.
    /// Disabled under Reduce Motion.
    @State private var autoAdvance = true
    private let autoTimer = Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()

    private var slides: [ShowcaseSlide] { ShowcaseSlide.all(copy) }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: Skip (right-aligned). ≥44pt tap target.
            HStack {
                Spacer()
                Button {
                    Haptics.tap()
                    onFinish()
                } label: {
                    Text(copy.skip)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.inkSoft)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    ShowcaseSlideView(slide: slide, active: page == index)
                        .tag(index)
                        .padding(.horizontal, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onReceive(autoTimer) { _ in
                guard autoAdvance, !reduceMotion, page < slides.count - 1 else { return }
                withAnimation { page += 1 }
            }
            .simultaneousGesture(
                // First manual swipe hands control to the user for good.
                DragGesture().onChanged { _ in autoAdvance = false }
            )

            Button {
                Haptics.tap()
                if page < slides.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < slides.count - 1 ? copy.showcaseContinue : copy.next)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(AppPalette.cream)
    }
}

// MARK: - One showcase slide (photo hero + headline + sample)

private struct ShowcaseSlideView: View {
    let slide: ShowcaseSlide
    /// True while this is the visible page. The sample is re-mounted on each
    /// activation (`.id(active)`) so its demo — the ScoreRing filling, chat
    /// bubbles appearing, the quiz answer revealing — REPLAYS as the user (or
    /// the auto-play) arrives, like a short product video.
    let active: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Photo hero band with the feature eyebrow + headline.
                VStack(alignment: .leading, spacing: 8) {
                    Spacer(minLength: 0)
                    Eyebrow(slide.eyebrow)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(slide.headline)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 200, alignment: .bottomLeading)
                .padding(18)
                .brandedPhoto(slide.photo, scrim: .hero, cornerRadius: 22)

                // The one concrete, clearly-labeled SAMPLE for this feature,
                // playing its staged demo every time the page becomes active.
                slide.sample
                    .id(active)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Demo reveal (staged element entrances inside a sample)

/// Opacity+rise entrance with a per-element delay, so a sample card plays out
/// like a tiny scene (question → answer, ring → bullets). Under Reduce Motion
/// everything shows at rest immediately.
private struct DemoReveal: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
            .onAppear {
                guard !reduceMotion else { shown = true; return }
                withAnimation(Motion.entrance.delay(delay)) { shown = true }
            }
    }
}

private extension View {
    func demoReveal(_ delay: Double) -> some View { modifier(DemoReveal(delay: delay)) }
}

// MARK: - Slide model + sample cards

private struct ShowcaseSlide: Identifiable {
    let id = UUID()
    let eyebrow: String
    let headline: String
    let photo: String
    let sample: AnyView

    static func all(_ copy: OnboardingCopy) -> [ShowcaseSlide] {
        [
            ShowcaseSlide(
                eyebrow: copy.showcaseSwingEyebrow,
                headline: copy.showcaseSwingHeadline,
                photo: "PhotoForehand",
                sample: AnyView(SwingSampleCard(copy: copy))
            ),
            ShowcaseSlide(
                eyebrow: copy.showcaseMatchEyebrow,
                headline: copy.showcaseMatchHeadline,
                photo: "PhotoMatch",
                sample: AnyView(MatchSampleCard(copy: copy))
            ),
            ShowcaseSlide(
                eyebrow: copy.showcaseDoublesEyebrow,
                headline: copy.showcaseDoublesHeadline,
                photo: "PhotoDoubles",
                sample: AnyView(DoublesSampleCard(copy: copy))
            ),
            ShowcaseSlide(
                eyebrow: copy.showcaseQuizEyebrow,
                headline: copy.showcaseQuizHeadline,
                photo: "PhotoCourt",
                sample: AnyView(QuizSampleCard(copy: copy))
            ),
            ShowcaseSlide(
                eyebrow: copy.showcaseCoachEyebrow,
                headline: copy.showcaseCoachHeadline,
                photo: "PhotoCoach",
                sample: AnyView(CoachSampleCard(copy: copy))
            ),
            ShowcaseSlide(
                eyebrow: copy.showcaseNumbersEyebrow,
                headline: copy.showcaseNumbersHeadline,
                photo: "PhotoHero",
                sample: AnyView(NumbersSampleCard(copy: copy))
            ),
        ]
    }
}

/// Shared "Example" pill so every sample reads as illustrative, not real data.
private struct SampleBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(AppPalette.clay)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(AppPalette.parchment))
    }
}

/// Shared parchment sample-card chrome (matches the paywall sample card).
private struct SampleCardChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private func sampleBullet(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: "checkmark.circle.fill")
            .appFont(16, weight: .semibold, design: .default)
            .foregroundStyle(AppPalette.moss)
        Text(text)
            .font(.subheadline)
            .foregroundStyle(AppPalette.ink)
            .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
    }
}

// AI Swing Analysis — ScoreRing 82 over a photo band + 2 coaching bullets.
private struct SwingSampleCard: View {
    let copy: OnboardingCopy
    var body: some View {
        SampleCardChrome {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    ScoreRing(size: 64, score: 82, accent: .white,
                              track: .white.opacity(0.28))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(copy.showcaseSwingSampleTitle)
                            .font(.caption.weight(.heavy))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.9))
                        Text("82 / 100")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer(minLength: 8)
                    SampleBadge(text: copy.sampleBadge)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandedPhoto("PhotoServe", scrim: .full, cornerRadius: 0)

                VStack(alignment: .leading, spacing: 10) {
                    sampleBullet(copy.showcaseSwingBullet1)
                        .demoReveal(0.5)
                    sampleBullet(copy.showcaseSwingBullet2)
                        .demoReveal(0.85)
                }
                .padding(16)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.showcaseSwingSampleTitle)
    }
}

// AI Match Coaching — a 2-line sample report snippet.
private struct MatchSampleCard: View {
    let copy: OnboardingCopy
    var body: some View {
        SampleCardChrome {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(copy.showcaseMatchSampleTitle, systemImage: "list.clipboard.fill")
                        .font(.caption.weight(.heavy))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.clay)
                    Spacer(minLength: 8)
                    SampleBadge(text: copy.sampleBadge)
                }
                VStack(alignment: .leading, spacing: 10) {
                    sampleBullet(copy.showcaseMatchLine1)
                        .demoReveal(0.35)
                    sampleBullet(copy.showcaseMatchLine2)
                        .demoReveal(0.7)
                }
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.showcaseMatchSampleTitle)
    }
}

// Doubles Compatibility — a sample compatibility ScoreRing + caption.
private struct DoublesSampleCard: View {
    let copy: OnboardingCopy
    var body: some View {
        SampleCardChrome {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    ScoreRing(size: 72, score: 88, accent: .white,
                              track: .white.opacity(0.28))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(copy.showcaseDoublesScoreLabel)
                            .font(.caption.weight(.heavy))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.9))
                        Text("88 / 100")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer(minLength: 8)
                    SampleBadge(text: copy.sampleBadge)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandedPhoto("PhotoDoubles", scrim: .full, cornerRadius: 0)

                Text(copy.showcaseDoublesCaption)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .demoReveal(0.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.showcaseDoublesScoreLabel)
    }
}

// Tennis IQ quiz / daily drill — a sample decision prompt + best answer.
private struct QuizSampleCard: View {
    let copy: OnboardingCopy
    var body: some View {
        SampleCardChrome {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(copy.showcaseQuizSampleTitle, systemImage: "brain.head.profile")
                        .font(.caption.weight(.heavy))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.clay)
                    Spacer(minLength: 8)
                    SampleBadge(text: copy.sampleBadge)
                }
                Text(copy.showcaseQuizPrompt)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .demoReveal(0.15)
                // The best-answer reveal lands a beat later — the "aha".
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .appFont(16, weight: .semibold, design: .default)
                        .foregroundStyle(AppPalette.moss)
                    Text(copy.showcaseQuizAnswer)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.mossTint)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .demoReveal(1.0)
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.showcaseQuizSampleTitle)
    }
}

// Honest-scale finale — REAL inventory numbers counting up (no invented user
// counts or rankings; App Review 2.3.1). The scale of what's inside carries
// the credibility.
private struct NumbersSampleCard: View {
    let copy: OnboardingCopy

    var body: some View {
        SampleCardChrome {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    CountUpStat(value: 156, label: copy.numbersScenarios, delay: 0.1)
                    CountUpStat(value: 75, label: copy.numbersDrills, delay: 0.3)
                }
                HStack(alignment: .top, spacing: 10) {
                    CountUpStat(value: 10, label: copy.numbersPrograms, delay: 0.5)
                    CountUpStat(value: 16, label: copy.numbersPatterns, delay: 0.7)
                }

                Label(copy.numbersCoach, systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.clay)
                    .demoReveal(0.9)

                Text(copy.numbersMethod)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .demoReveal(1.1)
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.showcaseNumbersHeadline)
    }
}

/// A stat tile whose number rolls up from 0 (kinetic, like ScoreRing).
/// Reduce Motion shows the final value immediately.
private struct CountUpStat: View {
    let value: Int
    let label: String
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(displayed)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(AppPalette.clay)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard !reduceMotion else { displayed = value; return }
            withAnimation(Motion.entrance.delay(delay)) { displayed = value }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

// AI Coach — a sample chat exchange (question bubble + reply).
private struct CoachSampleCard: View {
    let copy: OnboardingCopy
    var body: some View {
        SampleCardChrome {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(copy.showcaseCoachSampleTitle, systemImage: "bubble.left.and.text.bubble.right.fill")
                        .font(.caption.weight(.heavy))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.clay)
                    Spacer(minLength: 8)
                    SampleBadge(text: copy.sampleBadge)
                }
                // User question (clay bubble, trailing) — arrives first…
                Text(copy.showcaseCoachQuestion)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(AppPalette.clay)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .demoReveal(0.15)
                // …then the coach reply, like a live exchange.
                Text(copy.showcaseCoachReply)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(AppPalette.cream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .demoReveal(1.0)
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.showcaseCoachSampleTitle)
    }
}
