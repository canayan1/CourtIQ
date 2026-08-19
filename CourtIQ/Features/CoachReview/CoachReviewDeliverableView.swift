import SwiftUI
import AVFoundation

/// The review a player receives: scorecard → THE ONE THING → 3 micro-notes →
/// 1 drill → voice note. Reading order and word budget follow
/// docs/COACH-REVIEW-TEMPLATE.md §6 — skimmable in 30 seconds.
struct CoachReviewDeliverableView: View {
    let order: CoachReviewOrder
    let deliverable: CoachReviewDeliverable

    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var audio = CoachVoicePlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                scorecard
                oneThing
                if !deliverable.microNotes.isEmpty { microNotes }
                if let title = deliverable.drillTitle, !title.isEmpty { drill(title) }
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("coachreview.report_title"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if deliverable.voicePath != nil { voiceBar }
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(lang.t("coachreview.from_coach"))
            Text(order.stroke.capitalized)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.ink)
        }
    }

    /// Five bars, no prose. A `nil` score renders "—" (the coach could not
    /// judge it from this angle) rather than a guess.
    private var scorecard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(lang.t("coachreview.scorecard"))
            ForEach(deliverable.scorecard.rows, id: \.key) { row in
                HStack(spacing: 10) {
                    Text(lang.t(row.key))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                        .frame(width: 96, alignment: .leading)
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { pip in
                            Capsule()
                                .fill(pip <= (row.score ?? 0) ? AppPalette.clay : AppPalette.sand.opacity(0.6))
                                .frame(height: 8)
                        }
                    }
                    Text(row.score.map(String.init) ?? "—")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(row.score == nil ? .secondary : AppPalette.ink)
                        .frame(width: 18)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(lang.t(row.key)): \(row.score.map(String.init) ?? lang.t("coachreview.not_judged"))")
            }
        }
        .padding(16)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
    }

    /// The single highest-leverage fix — the reason the review is worth buying.
    private var oneThing: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("coachreview.one_thing"))
                .font(.caption.weight(.heavy))
                .kerning(1.1)
                .foregroundStyle(.white.opacity(0.85))

            Text(deliverable.oneThing)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let at = deliverable.oneThingAt {
                    Label(CoachReviewMicroNote(at: at, kind: "good", text: "").timestampLabel,
                          systemImage: "play.circle.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                if let cue = deliverable.oneThingCue, !cue.isEmpty {
                    Text("“\(cue)”")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(AppPalette.gold, in: Capsule())
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [AppPalette.clay, AppPalette.clayText],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22)
        )
    }

    private var microNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(lang.t("coachreview.moments"))
            ForEach(deliverable.microNotes) { note in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: note.isGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(note.isGood ? AppPalette.moss : AppPalette.gold)
                    Text(note.timestampLabel)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(note.text)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
    }

    private func drill(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(lang.t("coachreview.your_drill"))
            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            if let body = deliverable.drillBody, !body.isEmpty {
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.mossTint.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
    }

    /// Voice note pinned to the bottom — the warmth layer over the text signal.
    private var voiceBar: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.tap()
                audio.toggle()
            } label: {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(AppPalette.clay, in: Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("coachreview.voice_title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                Text(audio.statusText(lang: lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.regularMaterial)
    }
}

/// Streams the coach's voice note from its signed URL (named distinctly from
/// the match journal's own VoiceNotePlayer). Kept tiny — one file,
/// play/pause, no scrubbing (the notes carry the timestamps).
@MainActor
final class CoachVoicePlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    private var player: AVPlayer?

    func load(url: URL) {
        player = AVPlayer(url: url)
    }

    func toggle() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    func statusText(lang: LanguageManager) -> String {
        isPlaying ? lang.t("coachreview.voice_playing") : lang.t("coachreview.voice_hint")
    }
}
