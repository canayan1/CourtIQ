import SwiftUI

/// Profile-page card that turns the user's drill history into a
/// 6-dimension tactical read. Rendered only when at least one drill
/// has been completed — otherwise the card is empty and we collapse
/// it so the page doesn't show a card full of dashes.
///
/// Renders a bar grid (6 rows, one per category). We deliberately
/// chose bars over a radar chart for two reasons:
///   1. Radar charts visually exaggerate small differences and hide
///      "no data" categories.
///   2. Bar rows can carry the sample-count hint inline ("3 reps")
///      without crowding the chart.
struct TacticalProfileCard: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager

    var body: some View {
        let profile = drillManager.tacticalProfile
        let hasAnyData = profile.contains { ($0.score ?? 0) > 0 }
        if !hasAnyData {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                header
                VStack(spacing: 10) {
                    ForEach(profile) { row(for: $0) }
                }
                footnote
            }
            .padding(16)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(lang.t("drill.profile_kicker"), systemImage: "scope")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.clay)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(lang.t("drill.profile_title"))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(AppPalette.ink)
        }
    }

    // MARK: - Per-category row

    private func row(for entry: TacticalProfileEntry) -> some View {
        HStack(spacing: 10) {
            // Category label takes a fixed width so the bars line up.
            Text(lang.t(entry.category.localizationKey))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
                .frame(width: 110, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)

            // Bar.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppPalette.sand.opacity(0.5))
                    if let score = entry.score, score > 0 {
                        Capsule()
                            .fill(barTint(score))
                            .frame(width: geo.size.width * CGFloat(score / 5.0))
                    }
                }
            }
            .frame(height: 10)

            // Numeric score + sample-count hint
            VStack(alignment: .trailing, spacing: 0) {
                if let score = entry.score {
                    Text(String(format: "%.1f", score))
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppPalette.ink)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppPalette.inkSoft.opacity(0.5))
                }
                Text(String(format: lang.t("drill.profile_reps_format"), entry.sampleCount))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
            }
            .frame(width: 50, alignment: .trailing)
        }
        .opacity(entry.isEstablished ? 1.0 : 0.55)
    }

    /// Score tinting: red below 2.5, gold 2.5–3.5, moss above 3.5.
    /// Mirrors the green / yellow / red drill-feedback palette so the
    /// user reads "above 3.5 means you're consistently green there".
    private func barTint(_ score: Double) -> Color {
        if score < 2.5 { return AppPalette.alert }
        if score < 3.5 { return AppPalette.gold }
        return AppPalette.moss
    }

    private var footnote: some View {
        Text(lang.t("drill.profile_footnote"))
            .font(.caption2)
            .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }
}
