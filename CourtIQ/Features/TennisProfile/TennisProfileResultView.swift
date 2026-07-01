import SwiftUI

/// Renders a computed `TennisProfile`: a prominent level hero, the play-style
/// archetype, strength/growth chips, and a selectable list of suggested goals
/// the user can adopt. Visual style mirrors `PaywallView` and
/// `AICoachConsentView`: cream background, parchment cards with a sand stroke,
/// clay-accented primary actions.
struct TennisProfileResultView: View {
    let profile: TennisProfile

    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    private var copy: TennisProfileCopy { TennisProfileCopy(lang: lang.language) }
    private var result: TennisProfileResult { profile.result }

    /// Seeded from the suggestions' own `isSelected` flag.
    @State private var selectedGoalIDs: Set<String> = []
    @State private var didSave = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                levelHero
                styleCard
                strengthsCard
                growthCard
                goalsCard
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(copy.sectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedGoalIDs.isEmpty {
                selectedGoalIDs = Set(result.suggestedGoals.filter { $0.isSelected }.map { $0.id })
            }
        }
    }

    // MARK: Level hero

    private var levelHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Inline WHITE uppercase label (the Eyebrow's inkSoft is illegible on
            // the photo scrim).
            Text(copy.levelHeader)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.85))

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(copy.levelTitle(result.level))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(copy.levelNTRP(result.level))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Text(copy.levelBlurb(result.level))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Marquee level hero: duotone PhotoCourt with white foreground.
        .brandedPhoto("PhotoCourt", scrim: .hero, cornerRadius: 24)
    }

    // MARK: Style

    private var styleCard: some View {
        sectionCard {
            sectionHeader(copy.styleHeader)
            Text(copy.archetypeTitle(result.archetype))
                .font(.title3.bold())
                .foregroundStyle(AppPalette.ink)
            Text(copy.archetypeBlurb(result.archetype))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Strengths

    private var strengthsCard: some View {
        sectionCard {
            sectionHeader(copy.strengthsHeader)
            chipFlow(result.strengths, tint: AppPalette.moss)
        }
    }

    // MARK: Growth

    private var growthCard: some View {
        sectionCard {
            sectionHeader(copy.growthHeader)
            chipFlow(result.growthAreas, tint: AppPalette.clay)
        }
    }

    // MARK: Goals

    private var goalsCard: some View {
        sectionCard {
            sectionHeader(copy.goalsHeader)
            Text(copy.goalsSubhead)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(result.suggestedGoals) { goal in
                    goalRow(goal)
                }
            }

            Button {
                saveGoals()
            } label: {
                Text(copy.adoptGoals)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
            .padding(.top, 4)

            if didSave {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppPalette.moss)
                    Text(copy.aiTeaser)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppPalette.clay)
                    Text(copy.aiTeaser)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func goalRow(_ goal: TennisGoal) -> some View {
        let isSelected = selectedGoalIDs.contains(goal.id)
        return Button {
            toggle(goal)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .appFont(22, design: .default)
                    .foregroundStyle(isSelected ? AppPalette.clay : AppPalette.sand)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(copy.goalTitle(goal.titleKey))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(copy.goalDetail(goal.detailKey))
                        .font(.footnote)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.cream)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: Actions

    private func toggle(_ goal: TennisGoal) {
        if selectedGoalIDs.contains(goal.id) {
            selectedGoalIDs.remove(goal.id)
        } else {
            selectedGoalIDs.insert(goal.id)
        }
        didSave = false
    }

    private func saveGoals() {
        let selected = result.suggestedGoals
            .filter { selectedGoalIDs.contains($0.id) }
            .map { goal -> TennisGoal in
                var g = goal
                g.isSelected = true
                return g
            }
        TennisProfileStore.shared.updateAdoptedGoals(selected)
        withAnimation { didSave = true }
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

    /// Simple wrapping chip layout for a set of dimensions.
    private func chipFlow(_ dimensions: [TennisDimension], tint: Color) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(dimensions) { d in
                Text(copy.dimension(d))
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

/// Lightweight wrapping HStack so strength/growth chips flow onto new lines.
private struct FlowLayout: Layout {
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
