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
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
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

    /// Advance into the questionnaire bridge. Called by both the per-page
    /// Continue (on the last page) and the Skip button.
    let onFinish: () -> Void

    private var copy: OnboardingCopy { OnboardingCopy(lang: lang.language) }

    @State private var page = 0

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
                    ShowcaseSlideView(slide: slide)
                        .tag(index)
                        .padding(.horizontal, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

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

                // The one concrete, clearly-labeled SAMPLE for this feature.
                slide.sample
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 12)
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            guard !reduceMotion else { revealed = true; return }
            withAnimation(Motion.entrance.delay(Motion.stagger * 2)) { revealed = true }
        }
    }
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
            .font(.system(size: 16, weight: .semibold))
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
                    sampleBullet(copy.showcaseSwingBullet2)
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
                    sampleBullet(copy.showcaseMatchLine2)
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
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .semibold))
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
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.showcaseQuizSampleTitle)
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
                // User question (clay bubble, trailing).
                Text(copy.showcaseCoachQuestion)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(AppPalette.clay)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                // Coach reply (parchment bubble, leading).
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
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.showcaseCoachSampleTitle)
    }
}
