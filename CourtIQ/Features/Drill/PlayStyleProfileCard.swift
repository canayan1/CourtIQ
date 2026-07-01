import SwiftUI

/// Profile-page card that visualises the user's play-style fingerprint
/// — % distribution of shot types chosen across all Daily Drills,
/// plus a coarse archetype label once there's enough data (≥10
/// shot-type votes). Sibling to TacticalProfileCard: where that one
/// reads accuracy, this one reads preference.
struct PlayStyleProfileCard: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager

    var body: some View {
        let p = drillManager.playStyleProfile
        if p.totalShots == 0 {
            EmptyView()   // no v2 shots yet — hide entirely
        } else {
            VStack(alignment: .leading, spacing: 14) {
                header(profile: p)
                shotTypeBars(profile: p)
                if let acc = p.shotTypeAccuracy {
                    accuracyRow(acc)
                }
                footnote(profile: p)
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

    private func header(profile: PlayStyleProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(lang.t("drill.style_kicker"), systemImage: "person.crop.square.filled.and.at.rectangle.fill")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.clay)
                .textCase(.uppercase)
                .tracking(0.5)

            if let arc = profile.archetype {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t(arc.localizationKey))
                        .appFont(19, weight: .heavy)
                        .foregroundStyle(AppPalette.ink)
                    Text(lang.t(arc.summaryKey))
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(lang.t("drill.style_pending"))
                    .appFont(17, weight: .heavy)
                    .foregroundStyle(AppPalette.ink)
                Text(String(format: lang.t("drill.style_pending_progress_format"),
                            profile.totalShots, 10))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
        }
    }

    // MARK: - Shot type bars

    /// Horizontal bar grid — five rows, one per shot type, length
    /// proportional to selection % within the user's history.
    private func shotTypeBars(profile: PlayStyleProfile) -> some View {
        VStack(spacing: 8) {
            ForEach(ShotType.allCases) { shot in
                let pct = profile.percentages[shot] ?? 0
                shotTypeRow(shot: shot, pct: pct,
                            count: profile.counts[shot] ?? 0)
            }
        }
    }

    private func shotTypeRow(shot: ShotType, pct: Double, count: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: shot.iconName)
                .appFont(16, weight: .bold, design: .default)
                .foregroundStyle(AppPalette.clay)
                .frame(width: 22)
            Text(lang.t(shot.localizationKey))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
                .frame(width: 70, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppPalette.sand.opacity(0.5))
                    if pct > 0 {
                        Capsule()
                            .fill(AppPalette.clay)
                            .frame(width: max(geo.size.width * CGFloat(pct), 4))
                    }
                }
            }
            .frame(height: 8)
            Text("\(Int((pct * 100).rounded()))%")
                .appFont(12, weight: .heavy, design: .monospaced)
                .foregroundStyle(AppPalette.ink)
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
        .opacity(count > 0 ? 1.0 : 0.40)
    }

    // MARK: - Accuracy + footnote

    private func accuracyRow(_ acc: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(AppPalette.moss)
                .font(.caption.weight(.bold))
            Text(String(format: lang.t("drill.style_accuracy_format"),
                        Int((acc * 100).rounded())))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding(.top, 4)
    }

    private func footnote(profile: PlayStyleProfile) -> some View {
        Text(String(format: lang.t("drill.style_footnote_format"),
                    profile.totalShots))
            .font(.caption2)
            .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }
}
