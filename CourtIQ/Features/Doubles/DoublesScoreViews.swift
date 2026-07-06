import SwiftUI

/// Brand-native three-step read of a 0–100 compatibility score — the colour
/// carries the signal, the word (via `DoublesCopy`) stays encouraging. Mirrors
/// `SwingScoreTier` and reuses the same palette tiers.
enum DoublesCompatTier {
    case work    // < 55 — complementary, roles to sort
    case solid   // 55–74 — dependable pairing
    case great   // 75+ — games slot together

    static func from(score: Int) -> DoublesCompatTier {
        switch score {
        case ..<55:   return .work
        case 55..<75: return .solid
        default:      return .great
        }
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

/// Compact compatibility badge ("NN/100") used in partner list rows + report
/// list rows. Mirrors `SwingScoreBadge`.
struct DoublesScoreBadge: View {
    let score: Int
    let copy: DoublesCopy

    private var tier: DoublesCompatTier { .from(score: score) }

    var body: some View {
        Text(copy.scoreBadge(score))
            .font(.caption.weight(.bold))
            .foregroundStyle(tier.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tier.tint)
            .clipShape(Capsule())
    }
}
