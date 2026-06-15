import SwiftUI

/// The big, prominent "NN / 100" compatibility score with a label underneath.
/// Mirrors `SwingScoreView` but takes a `DoublesCopy` so the label reads
/// "Compatibility" rather than "Swing score".
struct DoublesScoreView: View {
    let score: Int
    let copy: DoublesCopy

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
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        // "Hero + select cards": the doubles compatibility score hero gets a
        // PhotoDoubles background (white ScoreRing + label over the scrim).
        .brandedPhoto("PhotoDoubles", scrim: .hero, cornerRadius: 16)
    }
}

/// Compact compatibility badge ("NN/100") used in partner list rows + report
/// list rows. Mirrors `SwingScoreBadge`.
struct DoublesScoreBadge: View {
    let score: Int
    let copy: DoublesCopy

    var body: some View {
        Text(copy.scoreBadge(score))
            .font(.caption.weight(.bold))
            .foregroundStyle(AppPalette.clay)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppPalette.clay.opacity(0.12))
            .clipShape(Capsule())
    }
}
