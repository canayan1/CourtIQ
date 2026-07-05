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

// MARK: - Score tier (traffic-light read)

/// A three-step, brand-native "traffic light" for the swing score so the bare
/// 0–100 number is instantly legible. The colour carries the signal; the word
/// stays growth-framed (we never label a swing "bad"). Pure/Foundation-safe
/// (the colour accessors are the only UIKit-touching part) so `SwingAnalysisCopy`
/// can key its labels off the same cases — one source of truth.
///
/// Thresholds are calibrated to the edge model's own scale (see the swing
/// system prompt: "most recreational players land 40–70; reserve 85+ for
/// genuinely advanced"). That keeps green *attainable* (70+, not gated at the
/// rare 85) and the low tier honest but *rare* rather than a constant alarm on
/// the core recreational audience.
enum SwingScoreTier {
    case building   // < 40  — below the typical recreational floor
    case solid      // 40–69 — the healthy recreational band (most players)
    case sharp      // 70+   — above typical recreational

    static func from(score: Int) -> SwingScoreTier {
        switch score {
        case ..<40:  return .building
        case 40..<70: return .solid
        default:     return .sharp
        }
    }

    /// Strong fill for the hero capsule (white text sits on top over the photo).
    var solidColor: Color {
        switch self {
        case .building: return AppPalette.clay
        case .solid:    return AppPalette.gold
        case .sharp:    return AppPalette.moss
        }
    }

    /// Soft background + readable foreground for the light-surface pill used in
    /// history rows (over cream, not a photo).
    var tint: Color {
        switch self {
        case .building: return AppPalette.clayTint
        case .solid:    return AppPalette.goldTint
        case .sharp:    return AppPalette.mossTint
        }
    }

    var text: Color {
        switch self {
        case .building: return AppPalette.clayText
        case .solid:    return AppPalette.goldText
        case .sharp:    return AppPalette.mossText
        }
    }
}

// MARK: - Score callout

/// The big, prominent "NN / 100" swing score with a label underneath. Shown
/// above the report on the live result screen and the saved-report detail.
struct SwingScoreView: View {
    let score: Int
    let copy: SwingAnalysisCopy

    private var tier: SwingScoreTier { .from(score: score) }

    var body: some View {
        VStack(spacing: 10) {
            // Kinetic peak moment: the ring fills 0→score and the number rolls
            // up on appear (Reduce-Motion-safe inside `ScoreRing`). Mirrors the
            // doubles compatibility score.
            ScoreRing(size: 120, score: score, accent: .white,
                      track: .white.opacity(0.28))

            Text(copy.scoreLabel)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .textCase(.uppercase)
                .tracking(0.5)

            // Traffic-light read: solid tier colour + white text reads clearly
            // over the photo scrim. The gloss line keeps meaning off colour
            // alone (accessibility) and the tone encouraging.
            VStack(spacing: 6) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(.white)
                        .frame(width: 7, height: 7)
                    Text(copy.scoreTierLabel(tier))
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(tier.solidColor, in: Capsule())

                Text(copy.scoreTierCaption(tier))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(copy.scoreTierLabel(tier)). \(copy.scoreTierCaption(tier))")
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        // Marquee peak moment: duotone photo hero behind the ScoreRing (ring +
        // label flipped to white over the `.hero` scrim).
        .brandedPhoto("PhotoServe", scrim: .hero, cornerRadius: 16)
    }
}

/// Compact score badge ("NN/100") used in history rows. Tinted by tier so the
/// list is scannable at a glance (green/amber/clay) — same traffic-light read
/// as the hero.
struct SwingScoreBadge: View {
    let score: Int
    let copy: SwingAnalysisCopy

    private var tier: SwingScoreTier { .from(score: score) }

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
