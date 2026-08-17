import SwiftUI

/// Brand-native three-step read of a 0–100 compatibility score — the colour
/// carries the signal, the word (via `DoublesCopy`) stays encouraging. Mirrors
/// `SwingScoreTier` and reuses the same palette tiers.
enum DoublesCompatTier: String {
    case work    // complementary, roles to sort
    case solid   // dependable pairing
    case great   // games slot together

    /// Legacy mapping for old saved reports that only stored a number.
    static func from(score: Int) -> DoublesCompatTier {
        switch score {
        case ..<55:   return .work
        case 55..<75: return .solid
        default:      return .great
        }
    }

    /// Reconstruct from a stored `tierRaw`, falling back to the legacy score.
    static func restore(tierRaw: String?, score: Int?) -> DoublesCompatTier? {
        if let tierRaw, let t = DoublesCompatTier(rawValue: tierRaw) { return t }
        if let score { return .from(score: score) }
        return nil
    }

    var solidColor: Color {
        switch self {
        case .work:  return AppPalette.clay
        case .solid: return AppPalette.gold
        case .great: return AppPalette.moss
        }
    }
    var tint: Color {
        switch self {
        case .work:  return AppPalette.clayTint
        case .solid: return AppPalette.goldTint
        case .great: return AppPalette.mossTint
        }
    }
    var text: Color {
        switch self {
        case .work:  return AppPalette.clayText
        case .solid: return AppPalette.goldText
        case .great: return AppPalette.mossText
        }
    }
}

/// The big, prominent "NN / 100" compatibility score with a label underneath.
/// Mirrors `SwingScoreView` but takes a `DoublesCopy` so the label reads
/// "Compatibility" rather than "Swing score".
struct DoublesScoreView: View {
    let score: Int
    let copy: DoublesCopy

    private var tier: DoublesCompatTier { .from(score: score) }

    var body: some View {
        VStack(spacing: 10) {
            // Kinetic peak moment: the ring fills 0→score and the number rolls
            // up on appear (Reduce-Motion-safe inside `ScoreRing`). On the photo
            // hero the ring flips to white accent + a translucent white track.
            ScoreRing(size: 116, score: score,
                      accent: .white, track: .white.opacity(0.28))

            Text(copy.scoreLabel)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.9))
                .textCase(.uppercase)
                .tracking(0.5)

            // Traffic-light read: solid tier colour + white text over the photo,
            // plus a one-line gloss (meaning isn't on colour alone).
            VStack(spacing: 6) {
                HStack(spacing: 7) {
                    Circle().fill(.white).frame(width: 7, height: 7)
                    Text(copy.compatTierLabel(tier))
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase).tracking(0.5)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(tier.solidColor, in: Capsule())

                Text(copy.compatTierCaption(tier))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(copy.compatTierLabel(tier)). \(copy.compatTierCaption(tier))")
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        // "Hero + select cards": the doubles compatibility score hero gets a
        // PhotoDoubles background (white ScoreRing + label over the scrim).
        .brandedPhoto("PhotoDoubles", scrim: .hero, cornerRadius: 16)
        // Peak-moment cue: a clean racket "pock" as the compatibility lands.
        .onAppear { AudioManager.shared.play(.sweetSpot) }
    }
}

/// Honest fit reveal — tier + the specific strengths and watch-outs behind it,
/// with NO 0–100 number (that number was misleading; see DoublesFit). Replaces
/// the old `DoublesScoreView` ring on the result screen.
struct DoublesFitView: View {
    let fit: DoublesFit
    let copy: DoublesCopy

    private var tier: DoublesCompatTier { fit.tier }

    var body: some View {
        VStack(spacing: 14) {
            DoublesTierBadge(tier: tier, copy: copy)

            // The specifics: what's working + what to sort out.
            VStack(alignment: .leading, spacing: 12) {
                if !fit.strengths.isEmpty {
                    factorBlock(copy.strengthsHeader, fit.strengths,
                                icon: "checkmark.circle.fill", color: AppPalette.moss)
                }
                if !fit.cautions.isEmpty {
                    factorBlock(copy.watchHeader, fit.cautions,
                                icon: "exclamationmark.triangle.fill", color: AppPalette.gold)
                }
                if !fit.hasUserProfile {
                    Text(copy.fitNeedsProfile)
                        .font(.caption).foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.parchment)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .onAppear { AudioManager.shared.play(.sweetSpot) }
    }

    private func factorBlock(_ header: String, _ items: [String],
                             icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header)
                .font(.caption.weight(.heavy)).textCase(.uppercase).tracking(0.4)
                .foregroundStyle(AppPalette.inkSoft)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon).font(.caption).foregroundStyle(color).padding(.top, 1)
                    Text(copy.factorPhrase(item))
                        .font(.subheadline).foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// The hero fit-tier badge over the PhotoDoubles scrim (word + caption, no
/// number). Reused by the fresh reveal (`DoublesFitView`) and historical
/// surfaces (report detail) so the read is consistent everywhere.
struct DoublesTierBadge: View {
    let tier: DoublesCompatTier
    let copy: DoublesCopy

    var body: some View {
        VStack(spacing: 8) {
            Text(copy.fitLabel)
                .font(.caption.weight(.heavy)).textCase(.uppercase).tracking(0.5)
                .foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 7) {
                Circle().fill(.white).frame(width: 7, height: 7)
                Text(copy.compatTierLabel(tier))
                    .font(.title3.weight(.heavy)).textCase(.uppercase).tracking(0.5)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(tier.solidColor, in: Capsule())
            Text(copy.compatTierCaption(tier))
                .font(.caption).foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center).padding(.horizontal, 24)
        }
        .padding(.vertical, 22).frame(maxWidth: .infinity)
        .brandedPhoto("PhotoDoubles", scrim: .hero, cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy.compatTierLabel(tier)). \(copy.compatTierCaption(tier))")
    }
}

/// Compact fit-tier chip (word, coloured) for partner/partnership list rows —
/// replaces the old numeric `DoublesScoreBadge`.
struct DoublesTierChip: View {
    let tier: DoublesCompatTier
    let copy: DoublesCopy

    var body: some View {
        Text(copy.compatTierLabel(tier))
            .font(.caption2.weight(.bold))
            .foregroundStyle(tier.text)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(tier.tint)
            .clipShape(Capsule())
    }
}

/// Compact compatibility badge used in partner list rows + report list rows.
/// Legacy records still carry a numeric score — we map it to the honest TIER
/// and never render the number (same policy as the report screen).
struct DoublesScoreBadge: View {
    let score: Int
    let copy: DoublesCopy

    private var tier: DoublesCompatTier { .from(score: score) }

    var body: some View {
        Text(copy.compatTierLabel(tier))
            .font(.caption.weight(.bold))
            .foregroundStyle(tier.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tier.tint)
            .clipShape(Capsule())
    }
}
