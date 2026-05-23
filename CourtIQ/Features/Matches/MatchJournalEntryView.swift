import SwiftUI
import AVFoundation

/// Long-form match journal entry. Used for both creating a new journal
/// entry (passing `entry: nil`) and editing/viewing an existing one. The
/// view follows the "neredeyse hiç yazı" rule: no labels, only icon
/// headers + placeholder-led inputs. The user's writing dominates the
/// screen.
struct MatchJournalEntryView: View {
    /// `nil` for new entry; populated for edit/view.
    let entry: MatchEntry?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager

    @State private var date: Date = Date()
    @State private var opponentName: String = ""
    @State private var surface: MatchSurface = .hard
    @State private var result: MatchResult = .won
    @State private var score: String = ""
    @State private var preMatchNotes: String = ""
    @State private var postMatchNotes: String = ""
    @State private var takeaway: String = ""

    // Voice notes — file names on disk, nil until user records one.
    @State private var preMatchAudioFile: String?
    @State private var postMatchAudioFile: String?

    // One recorder per scope so the two sections can't compete for the
    // mic / share waveform state.
    @StateObject private var preRecorder = VoiceNoteRecorder()
    @StateObject private var postRecorder = VoiceNoteRecorder()

    // Stable entry ID computed once on hydrate so a brand-new entry
    // can record audio against a known ID before save().
    @State private var stableEntryID: String = UUID().uuidString

    @State private var voiceErrorMessage: String?
    @State private var showDeleteConfirm = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case opponent, score, preMatch, postMatch, takeaway
    }

    private var isEditing: Bool { entry != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                metaBlock
                preMatchBlock
                postMatchBlock
                takeawayBlock
                if isEditing { deleteButton }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(AppPalette.cream)
        .navigationTitle(isEditing
                         ? lang.t("matches.journal_title_edit")
                         : lang.t("matches.journal_title_new"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !isEditing {
                    Button(lang.t("common.cancel")) { dismiss() }
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(lang.t("common.save")) { save() }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
                    .disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(lang.t("common.done")) { focusedField = nil }
            }
        }
        .onAppear(perform: hydrate)
        .confirmationDialog(
            lang.t("matches.delete_title"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(lang.t("common.delete"), role: .destructive) {
                if let id = entry?.id {
                    matches.delete(id)
                    dismiss()
                }
            }
            Button(lang.t("common.cancel"), role: .cancel) {}
        }
        .alert(
            lang.t("voice.error_title"),
            isPresented: Binding(
                get: { voiceErrorMessage != nil },
                set: { if !$0 { voiceErrorMessage = nil } }
            )
        ) {
            Button(lang.t("common.ok"), role: .cancel) {}
        } message: {
            Text(voiceErrorMessage ?? "")
        }
    }

    // MARK: - Meta block (date, opponent, surface, W/L, score)

    private var metaBlock: some View {
        VStack(spacing: 14) {
            DatePicker(
                "",
                selection: $date,
                in: ...Date(),
                displayedComponents: .date
            )
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField(
                lang.t("matches.opponent_placeholder"),
                text: $opponentName
            )
            .focused($focusedField, equals: .opponent)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .padding(12)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 12) {
                surfaceSegment
                resultSegment
            }

            TextField(
                lang.t("matches.score_placeholder"),
                text: $score
            )
            .focused($focusedField, equals: .score)
            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
            .padding(12)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var surfaceSegment: some View {
        HStack(spacing: 6) {
            ForEach(MatchSurface.allCases) { s in
                Button {
                    Haptics.tap()
                    surface = s
                } label: {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(surfaceColor(s))
                        .frame(width: 40, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    surface == s ? AppPalette.ink : Color.clear,
                                    lineWidth: 2.5
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var resultSegment: some View {
        HStack(spacing: 0) {
            resultButton(value: .won,  label: "W", color: AppPalette.moss)
            resultButton(value: .lost, label: "L", color: AppPalette.alert)
        }
        .padding(4)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func resultButton(value: MatchResult, label: String, color: Color) -> some View {
        Button {
            Haptics.tap()
            result = value
        } label: {
            Text(label)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(result == value ? .white : AppPalette.inkSoft)
                .frame(width: 40, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(result == value ? color : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func surfaceColor(_ s: MatchSurface) -> Color {
        switch s {
        case .clay:  return AppPalette.CourtSurface.clay.base
        case .grass: return AppPalette.CourtSurface.grass.base
        case .hard:  return AppPalette.CourtSurface.hard.base
        }
    }

    // MARK: - Note blocks (icon-led, placeholder-driven)

    private var preMatchBlock: some View {
        noteSection(
            iconName: "target",
            iconColor: AppPalette.clay,
            labelKey: "matches.pre_match_label",
            placeholderKey: "matches.pre_match_placeholder",
            text: $preMatchNotes,
            field: .preMatch,
            audioFile: $preMatchAudioFile,
            recorder: preRecorder,
            scope: .pre
        )
    }

    private var postMatchBlock: some View {
        noteSection(
            iconName: "checkmark.seal.fill",
            iconColor: AppPalette.moss,
            labelKey: "matches.post_match_label",
            placeholderKey: "matches.post_match_placeholder",
            text: $postMatchNotes,
            field: .postMatch,
            audioFile: $postMatchAudioFile,
            recorder: postRecorder,
            scope: .post
        )
    }

    private var takeawayBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppPalette.gold)
                    .font(.subheadline.weight(.bold))
                Text(lang.t("matches.takeaway_label"))
                    .font(.caption.weight(.heavy))
                    .tracking(0.6)
                    .foregroundStyle(AppPalette.inkSoft)
                    .textCase(.uppercase)
            }

            TextField(
                lang.t("matches.takeaway_placeholder"),
                text: $takeaway,
                axis: .vertical
            )
            .focused($focusedField, equals: .takeaway)
            .lineLimit(2, reservesSpace: true)
            .font(.subheadline)
            .padding(14)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onChange(of: takeaway) { _, newValue in
                if newValue.count > 200 {
                    takeaway = String(newValue.prefix(200))
                }
            }
        }
    }

    private func noteSection(
        iconName: String,
        iconColor: Color,
        labelKey: String,
        placeholderKey: String,
        text: Binding<String>,
        field: Field,
        audioFile: Binding<String?>,
        recorder: VoiceNoteRecorder,
        scope: MatchMediaStore.AudioScope
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .font(.subheadline.weight(.bold))
                Text(lang.t(labelKey))
                    .font(.caption.weight(.heavy))
                    .tracking(0.6)
                    .foregroundStyle(AppPalette.inkSoft)
                    .textCase(.uppercase)
                Spacer()
                voiceControl(recorder: recorder, scope: scope, text: text, audioFile: audioFile)
            }

            if recorder.state == .recording {
                recordingIndicator(recorder: recorder)
            }

            TextField(
                lang.t(placeholderKey),
                text: text,
                axis: .vertical
            )
            .focused($focusedField, equals: field)
            .lineLimit(6, reservesSpace: true)
            .font(.subheadline)
            .padding(14)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Existing audio playback chip (shown only when we have a
            // saved file). Tap to play, long-press to discard.
            if let fileName = audioFile.wrappedValue {
                audioChip(fileName: fileName, audioFile: audioFile)
            }
        }
    }

    // MARK: - Voice note controls

    /// Mic button. Tap to start, tap again to stop. When a recording
    /// already exists it shows a "re-record" affordance instead.
    @ViewBuilder
    private func voiceControl(
        recorder: VoiceNoteRecorder,
        scope: MatchMediaStore.AudioScope,
        text: Binding<String>,
        audioFile: Binding<String?>
    ) -> some View {
        switch recorder.state {
        case .recording:
            Button {
                Task {
                    await recorder.stop()
                    applyRecorderResult(recorder, text: text, audioFile: audioFile)
                }
            } label: {
                Label("\(Int(recorder.elapsed))s", systemImage: "stop.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppPalette.alert))
            }
            .buttonStyle(.plain)
        case .transcribing, .requestingPermission:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7)
                Text(lang.t("voice.transcribing"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
            }
        default:
            Button {
                Task {
                    await recorder.start(entryID: stableEntryID, scope: scope)
                }
            } label: {
                Image(systemName: audioFile.wrappedValue == nil ? "mic.fill" : "mic.badge.plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppPalette.clay)
                    .padding(8)
                    .background(Circle().fill(AppPalette.clay.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(lang.t(audioFile.wrappedValue == nil
                                       ? "voice.record_start"
                                       : "voice.record_replace"))
        }
    }

    /// Thin live waveform replacement — three pulsing dots whose size
    /// reacts to mic input level. Cheap, expressive, no Canvas overhead.
    private func recordingIndicator(recorder: VoiceNoteRecorder) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(AppPalette.alert)
                    .frame(width: 6 + CGFloat(recorder.recordingLevel * 10),
                           height: 6 + CGFloat(recorder.recordingLevel * 10))
                    .opacity(0.5 + 0.5 * Double((i == 1) ? 1 : recorder.recordingLevel))
                    .animation(.easeInOut(duration: 0.12), value: recorder.recordingLevel)
            }
            Text(lang.t("voice.recording_hint"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppPalette.alert)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    /// Inline chip representing a saved audio attachment. Tap to play
    /// (handled by `VoiceNotePlayer.shared.toggle(...)`); X icon
    /// deletes the file and clears the binding.
    private func audioChip(fileName: String, audioFile: Binding<String?>) -> some View {
        HStack(spacing: 8) {
            Button {
                VoiceNotePlayer.shared.toggle(fileName: fileName)
            } label: {
                Label(lang.t("voice.play"), systemImage: "play.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.clay)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                MatchMediaStore.removeAudio(named: [fileName])
                audioFile.wrappedValue = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(lang.t("voice.discard"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppPalette.clay.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Apply a finished recorder state into the bound text + audio file.
    /// If transcription succeeded, we *append* (with a newline) when the
    /// user has typed something already, so dictation never silently
    /// overwrites their typing.
    private func applyRecorderResult(
        _ recorder: VoiceNoteRecorder,
        text: Binding<String>,
        audioFile: Binding<String?>
    ) {
        if case let .finished(transcript, fileName) = recorder.state {
            audioFile.wrappedValue = fileName
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let existing = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            text.wrappedValue = existing.isEmpty ? trimmed : existing + "\n" + trimmed
        } else if case let .failed(message) = recorder.state {
            voiceErrorMessage = message
        }
    }

    // MARK: - Delete (edit mode only)

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label(lang.t("common.delete"), systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.alert)
    }

    // MARK: - Save / hydrate

    private var canSave: Bool {
        // At minimum we want a non-empty takeaway OR opponent OR any note.
        // Don't let users save totally blank entries.
        !takeaway.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !preMatchNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !postMatchNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let trimmedTakeaway = takeaway.trimmingCharacters(in: .whitespacesAndNewlines)
        let newEntry = MatchEntry(
            id: entry?.id ?? stableEntryID,
            date: date,
            opponentName: opponentName.trimmingCharacters(in: .whitespacesAndNewlines),
            surface: surface,
            result: result,
            score: score.trimmingCharacters(in: .whitespacesAndNewlines),
            serveRating: entry?.serveRating,
            returnRating: entry?.returnRating,
            movementRating: entry?.movementRating,
            mentalRating: entry?.mentalRating,
            preMatchNotes: preMatchNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            postMatchNotes: postMatchNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            takeaway: trimmedTakeaway,
            preMatchAudioFile: preMatchAudioFile,
            postMatchAudioFile: postMatchAudioFile,
            isQuickLog: false
        )
        matches.save(newEntry)
        Haptics.confirm()
        dismiss()
    }

    private func hydrate() {
        // Always seed the stable entry ID so voice notes can attach to it
        // even before the first save.
        stableEntryID = entry?.id ?? UUID().uuidString

        guard let entry, date != entry.date else { return }
        date = entry.date
        opponentName = entry.opponentName
        surface = entry.surface
        result = entry.result
        score = entry.score
        preMatchNotes = entry.preMatchNotes
        postMatchNotes = entry.postMatchNotes
        takeaway = entry.takeaway
        preMatchAudioFile = entry.preMatchAudioFile
        postMatchAudioFile = entry.postMatchAudioFile
    }
}

// MARK: - VoiceNotePlayer

/// Singleton playback shim — there's only ever one audio note playing
/// at a time, so a global player keeps tap-to-toggle behaviour simple
/// without each chip wrestling its own AVAudioPlayer instance.
@MainActor
final class VoiceNotePlayer {
    static let shared = VoiceNotePlayer()
    private var player: AVAudioPlayer?
    private var currentFile: String?

    private init() {}

    /// Toggle playback. If the same file is already playing, pause; if a
    /// different file is playing, switch; if nothing is playing, start.
    func toggle(fileName: String) {
        if currentFile == fileName, player?.isPlaying == true {
            player?.pause()
            return
        }
        guard let url = MatchMediaStore.audioURL(forFileName: fileName) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            p.play()
            player = p
            currentFile = fileName
        } catch {
            // Playback is non-critical; failing silently is fine — the
            // user can still see the transcript and re-record if needed.
        }
    }
}
