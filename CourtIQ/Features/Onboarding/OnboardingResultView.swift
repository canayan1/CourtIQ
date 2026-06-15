import SwiftUI

/// The personalized result reveal — the payoff after the labor-illusion. Shows
/// the deterministic `TennisProfile.result` (level + NTRP, archetype, strength
/// and growth chips) plus a "Tennis IQ" before/after projection that reflects
/// the user's goal and top weakness back at them. The profile is saved here
/// (with `adoptedGoals = result.suggestedGoals`) so downstream features — the
/// AI Coach, goal tracking — have it immediately. `onContinue` advances to the
/// evidence carousel.
struct OnboardingResultView: View {
    @EnvironmentObject private var lang: LanguageManager

    let profile: TennisProfile
    let goal: OnboardingGoal
    let topWeaknessLabel: String
    let onContinue: () -> Void

    private var copy: OnboardingCopy { OnboardingCopy(lang: lang.language) }
    private var tpCopy: TennisProfileCopy { TennisProfileCopy(lang: lang.language) }
    private var result: TennisProfileResult { profile.result }

    /// Animated fill for the projection bars.
    @State private var revealBars = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                kicker
                levelHero
                planLine
                tennisIQCard
                styleCard
                strengthsCard
                growthCard

                Button(action: onContinue) {
                    Text(copy.resultContinue)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.2)) { revealBars = true }
        }
    }

    // MARK: Header pieces

    private var kicker: some View {
        Text(copy.resultReadyKicker)
            .font(.system(.caption, design: .rounded).weight(.bold))
            .tracking(1.5)
            .foregroundStyle(AppPalette.clay)
    }

    private var levelHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.levelHeader)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.85))

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(tpCopy.levelTitle(result.level))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(tpCopy.levelNTRP(result.level))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Text(tpCopy.levelBlurb(result.level))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Marquee result hero: duotone hero photo + .hero scrim, light text.
        .brandedPhoto("PhotoHero", scrim: .hero, cornerRadius: 24)
    }

    private var planLine: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.moss)
                .padding(.top, 1)
            Text(copy.resultPlanLine(goal: copy.resultGoalPhrase(goal),
                                     weakness: topWeaknessLabel.lowercased()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.moss.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Tennis IQ projection

    private var tennisIQCard: some View {
        sectionCard {
            sectionHeader(copy.tennisIQHeader)

            // Two labeled bars: today vs. an honest projection a few weeks out.
            // Baseline scales with the computed level so it feels personalized.
            let baseline = iqBaseline
            let target = min(baseline + 28, 92)

            iqBar(label: copy.iqToday, value: baseline, fillColor: AppPalette.inkSoft)
            iqBar(label: copy.iqTarget(copy.iqTimeframe), value: target, fillColor: AppPalette.clay)

            Text(copy.iqProjectionNote)
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A baseline 0–100 "Tennis IQ" derived from the computed level so the
    /// before/after feels grounded in their answers (not a random number).
    private var iqBaseline: Int {
        switch result.level {
        case .new:          return 28
        case .improver:     return 40
        case .intermediate: return 52
        case .solidClub:    return 62
        case .advancedClub: return 70
        }
    }

    private func iqBar(label: String, value: Int, fillColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Spacer()
                Text("\(value)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(fillColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppPalette.sand.opacity(0.6))
                    Capsule()
                        .fill(fillColor)
                        .frame(width: geo.size.width * (revealBars ? CGFloat(value) / 100 : 0))
                }
            }
            .frame(height: 10)
        }
    }

    // MARK: Profile cards

    private var styleCard: some View {
        sectionCard {
            sectionHeader(copy.styleHeader)
            Text(tpCopy.archetypeTitle(result.archetype))
                .font(.title3.bold())
                .foregroundStyle(AppPalette.ink)
            Text(tpCopy.archetypeBlurb(result.archetype))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var strengthsCard: some View {
        sectionCard {
            sectionHeader(copy.strengthsHeader)
            chipFlow(result.strengths, tint: AppPalette.moss)
        }
    }

    private var growthCard: some View {
        sectionCard {
            sectionHeader(copy.growthHeader)
            chipFlow(result.growthAreas, tint: AppPalette.clay)
        }
    }

    // MARK: Reusable pieces

    private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AppPalette.ink)
    }

    private func chipFlow(_ dimensions: [TennisDimension], tint: Color) -> some View {
        OnboardingFlowLayout(spacing: 8) {
            ForEach(dimensions) { d in
                Text(tpCopy.dimension(d))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(tint.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
    }
}

/// Lightweight wrapping layout for the strength/growth chips. Local to the
/// onboarding flow to avoid colliding with `FlowLayout` defined elsewhere.
struct OnboardingFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalWidth = max(totalWidth, rowWidth - spacing)
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalWidth = max(totalWidth, rowWidth - spacing)
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? totalWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
