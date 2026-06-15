import SwiftUI

/// The big, prominent "NN / 100" compatibility score with a label underneath.
/// Mirrors `SwingScoreView` but takes a `DoublesCopy` so the label reads
/// "Compatibility" rather than "Swing score".
struct DoublesScoreView: View {
    let score: Int
    let copy: DoublesCopy

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(score)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppPalette.clay)
                Text(copy.scoreOutOf)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Text(copy.scoreLabel)
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
