import SwiftUI

/// The big, prominent "NN / 100" compatibility score with a label underneath.
/// Mirrors `SwingScoreView` but takes a `DoublesCopy` so the label reads
/// "Compatibility" rather than "Swing score".
struct DoublesScoreView: View {
    let score: Int
    let copy: DoublesCopy
    /// When true, the score hero sits on a duotone doubles photo (`.hero` scrim)
    /// with the ScoreRing + label flipped to white for legibility.
    var onPhoto: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            // Kinetic peak moment: the ring fills 0→score and the number rolls
            // up on appear (Reduce-Motion-safe inside `ScoreRing`).
            if onPhoto {
                ScoreRing(size: 116, score: score, accent: .white,
                          track: .white.opacity(0.28))
            } else {
                ScoreRing(size: 116, score: score)
            }

            Text(copy.scoreLabel)
                .font(.caption.weight(.heavy))
                .foregroundStyle(onPhoto ? .white.opacity(0.9) : AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .modifier(DoublesScoreBackground(onPhoto: onPhoto))
    }
}

/// Swaps the score hero's background: a duotone doubles photo (`.hero`) when on
/// a photo surface, else the original parchment + sand stroke.
private struct DoublesScoreBackground: ViewModifier {
    let onPhoto: Bool

    func body(content: Content) -> some View {
        if onPhoto {
            content.brandedPhoto("PhotoDoubles", scrim: .hero, cornerRadius: 16)
        } else {
            content
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

/// Compact compatibility badge ("NN/100") used in partner list rows + report
/// list rows. Mirrors `SwingScoreBadge`.
struct DoublesScoreBadge: View {
    let score: Int
    let copy: DoublesCopy
    /// When the badge sits on a duotone photo surface, it inverts to a white
    /// fill + clay text so it clears contrast over the dark scrim.
    var onPhoto: Bool = false

    var body: some View {
        Text(copy.scoreBadge(score))
            .font(.caption.weight(.bold))
            .foregroundStyle(onPhoto ? AppPalette.clay : AppPalette.clay)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(onPhoto ? AnyShapeStyle(.white) : AnyShapeStyle(AppPalette.clay.opacity(0.12)))
            .clipShape(Capsule())
    }
}
