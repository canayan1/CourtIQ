import SwiftUI

/// New onboarding step: 6-category tactical self-assessment. Shown
/// after the plan reveal and before the tour. The user drags six
/// sliders (one per TacticalCategory) and submits — produces a
/// baseline that the AI Coach + Profile card consume until real
/// drill / quiz signal accumulates.
///
/// Quiet UX: a slider per category with the manual's category name
/// + one-line description from the localisation file. "Not sure"
/// → leave at default 3. A "Skip" link lets the user bypass; an
/// empty SelfAssessment is treated as "user didn't tell us" and
/// the AI Coach falls back to neutral baselines.
struct SelfAssessmentStep: View {
    let dotIndex: Int
    let onBack: () -> Void
    let onNext: () -> Void

    @EnvironmentObject private var lang: LanguageManager
    @State private var ratings: [TacticalCategory: Int] = [
        .openCourt: 3, .defense: 3, .approach: 3,
        .patterns: 3, .netGame: 3, .return: 3,
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    explainer
                    VStack(spacing: 14) {
                        ForEach(TacticalCategory.allCases) { cat in
                            ratingRow(cat)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            bottomCTA
        }
        .background(AppPalette.cream)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                ZStack {
                    Circle()
                        .fill(AppPalette.inkSoft.opacity(0.08))
                        .frame(width: 34, height: 34)
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                }
            }
            OnboardingDots(current: dotIndex)
            Spacer()
            Button(lang.t("onboarding.skip"), action: skip)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    // MARK: - Header + explainer

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(lang.t("self_assess.kicker"), systemImage: "scope")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(AppPalette.clay)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(lang.t("self_assess.title"))
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(AppPalette.ink)
        }
    }

    private var explainer: some View {
        Text(lang.t("self_assess.body"))
            .font(.subheadline)
            .foregroundStyle(AppPalette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Per-category slider row

    private func ratingRow(_ cat: TacticalCategory) -> some View {
        let value = ratings[cat] ?? 3
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(lang.t(cat.localizationKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Spacer()
                Text("\(value)/5")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(AppPalette.clay)
                    .monospacedDigit()
            }
            Text(lang.t(cat.summaryKey))
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        Haptics.tap()
                        ratings[cat] = i
                    } label: {
                        Circle()
                            .fill(i <= value ? AppPalette.clay : AppPalette.sand)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(lang.t(cat.localizationKey)): \(i)")
                }
            }
        }
        .padding(12)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 0) {
            Button(action: submit) {
                Text(lang.t("self_assess.submit"))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppPalette.clay)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableCardStyle())
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background(.thinMaterial)
    }

    private func submit() {
        let stringKeys = Dictionary(uniqueKeysWithValues:
            ratings.map { ($0.key.rawValue, $0.value) })
        SelfAssessmentStore.shared.save(SelfAssessment(
            scoresByCategory: stringKeys,
            completedAt: Date()
        ))
        Haptics.confirm()
        onNext()
    }

    private func skip() {
        // Persist an empty assessment so we don't re-prompt the user
        // on every relaunch — but the AI Coach treats it as "user
        // opted out, fall back to neutral baselines".
        SelfAssessmentStore.shared.save(SelfAssessment(
            scoresByCategory: [:],
            completedAt: Date()
        ))
        onNext()
    }
}
