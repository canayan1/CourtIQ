import SwiftUI

// MARK: - Markdown-ish renderer

/// Renders the AI swing-analysis text. The edge function emits **bold headers**
/// and bullet "•" lines. We render line-by-line: blank lines become spacing,
/// bullet lines get a hanging "•", and inline `**bold**` spans are parsed to
/// bold via AttributedString (with a graceful plain-text fallback). Shared by
/// the live result screen and the saved-report detail screen.
struct SwingReportText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
    }

    private var lines: [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
    }

    @ViewBuilder
    private func lineView(_ raw: String) -> some View {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Color.clear.frame(height: 4)
        } else if trimmed.hasPrefix("•") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let body = String(trimmed.dropFirst(trimmed.hasPrefix("•") ? 1 : 2))
                .trimmingCharacters(in: .whitespaces)
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
                styled(body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            styled(trimmed)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Parse `**bold**` inline spans. Falls back to plain text if the markdown
    /// parser can't handle the string.
    private func styled(_ s: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
                .font(.subheadline)
                .foregroundColor(AppPalette.ink)
        }
        return Text(s)
            .font(.subheadline)
            .foregroundColor(AppPalette.ink)
    }
}

// MARK: - Score callout

/// The big, prominent "NN / 100" swing score with a label underneath. Shown
/// above the report on the live result screen and the saved-report detail.
struct SwingScoreView: View {
    let score: Int
    let copy: SwingAnalysisCopy

    var body: some View {
        VStack(spacing: 10) {
            // Kinetic peak moment: the ring fills 0→score and the number rolls
            // up on appear (Reduce-Motion-safe inside `ScoreRing`). Mirrors the
            // doubles compatibility score. White over the duotone serve hero.
            ScoreRing(size: 120, score: score, accent: .white,
                      track: .white.opacity(0.28))

            Text(copy.scoreLabel)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.9))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        // Marquee score hero: duotone serve photo + .hero scrim behind the ring.
        .brandedPhoto("PhotoServe", scrim: .hero, cornerRadius: 16)
    }
}

/// Compact score badge ("NN/100") used in history rows.
struct SwingScoreBadge: View {
    let score: Int
    let copy: SwingAnalysisCopy

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
