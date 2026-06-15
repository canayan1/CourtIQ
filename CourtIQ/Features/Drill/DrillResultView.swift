import SwiftUI

/// Shown when the user completes the daily 5-scenario tap drill. Big
/// numeric score, emoji string, shareable card, and a "done" button.
struct DrillResultView: View {
    let session: DrillSession
    let drills: [CourtTapDrill]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 22) {
                    scoreHero
                    emojiRow
                    shareSection
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 60)
            }
            bottomCTA
        }
        .background(AppPalette.cream)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
            }
            Spacer()
            Text("Drill #\(session.dayNumber)")
                .font(.caption.weight(.heavy))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.inkSoft)
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, 18)
        .padding(.top, 62)
        .padding(.bottom, 14)
    }

    private var scoreHero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(AppPalette.sand, lineWidth: 8)
                    .frame(width: 168, height: 168)
                Circle()
                    .trim(from: 0, to: CGFloat(session.score) / CGFloat(session.maxScore))
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 168, height: 168)

                VStack(spacing: 0) {
                    Text("\(session.score)")
                        .font(.system(size: 50, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .monospacedDigit()
                    Text("/ \(session.maxScore)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.inkSoft)
                        .monospacedDigit()
                }
            }

            Text(scoreLabel)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(scoreColor)
        }
        .padding(.top, 16)
    }

    private var emojiRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(session.taps.enumerated()), id: \.offset) { _, tap in
                Text(tap.zone.emoji)
                    .font(.system(size: 32))
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var shareSection: some View {
        VStack(spacing: 10) {
            ShareLink(item: shareableText) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(lang.t("drill.share"))
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppPalette.ink)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var bottomCTA: some View {
        Button {
            dismiss()
        } label: {
            Text(lang.t("common.done"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.bottom, 36)
    }

    // MARK: - Computed values

    private var scoreColor: Color {
        let pct = Double(session.score) / Double(session.maxScore)
        if pct >= 0.8 { return AppPalette.moss }
        if pct >= 0.5 { return AppPalette.gold }
        return AppPalette.alert
    }

    private var scoreLabel: String {
        let pct = Double(session.score) / Double(session.maxScore)
        if pct >= 0.9 { return lang.t("drill.label_excellent") }
        if pct >= 0.7 { return lang.t("drill.label_strong") }
        if pct >= 0.5 { return lang.t("drill.label_decent") }
        return lang.t("drill.label_keep_going")
    }

    private var shareableText: String {
        let pct = Int((Double(session.score) / Double(session.maxScore)) * 100)
        return """
        DropVolley · Drill #\(session.dayNumber)
        🎾 \(session.emojiString) \(pct)%
        courtiq.app
        """
    }
}
