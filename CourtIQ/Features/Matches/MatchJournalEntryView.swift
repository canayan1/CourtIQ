import SwiftUI

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
            field: .preMatch
        )
    }

    private var postMatchBlock: some View {
        noteSection(
            iconName: "checkmark.seal.fill",
            iconColor: AppPalette.moss,
            labelKey: "matches.post_match_label",
            placeholderKey: "matches.post_match_placeholder",
            text: $postMatchNotes,
            field: .postMatch
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
        field: Field
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
            id: entry?.id ?? UUID().uuidString,
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
            isQuickLog: false
        )
        matches.save(newEntry)
        Haptics.confirm()
        dismiss()
    }

    private func hydrate() {
        guard let entry, date != entry.date else { return }
        date = entry.date
        opponentName = entry.opponentName
        surface = entry.surface
        result = entry.result
        score = entry.score
        preMatchNotes = entry.preMatchNotes
        postMatchNotes = entry.postMatchNotes
        takeaway = entry.takeaway
    }
}
