import SwiftUI

/// Manual ChatGPT paste import — Phase 3 of the AI Coach work.
/// The user copies the most useful chunk of their existing ChatGPT
/// tennis conversation, pastes it here, and saves it as a single
/// "imported context" row in Supabase. Every subsequent AI Coach
/// chat then loads this row server-side as cached context, so the
/// coach behaves like it remembers the user's pre-DropVolley tennis
/// history.
///
/// Why this isn't AI-summarised yet: keeping v1 simple. A future
/// pass can add a one-shot "summarise this paste into ~200 words"
/// Edge Function call so the per-chat token cost stays flat as
/// users paste more content. For now we hard-cap the paste at
/// 1500 characters (~400 tokens) — fits comfortably in the cached
/// prompt prefix without pushing per-message cost over target.
struct AICoachImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var aiClient: AIChatClient

    @State private var pasted: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedSuccessfully = false

    private let maxChars = 1500

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    pasteField
                    helperRow
                    if let err = errorMessage { errorBanner(err) }
                    saveButton
                    privacyNote
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(AppPalette.cream)
            .navigationTitle(lang.t("ai.import_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(lang.t("common.cancel")) { dismiss() }
                }
            }
            .alert(lang.t("ai.import_saved_title"),
                   isPresented: $savedSuccessfully) {
                Button(lang.t("common.done")) { dismiss() }
            } message: {
                Text(lang.t("ai.import_saved_body"))
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(lang.t("ai.import_kicker"), systemImage: "doc.append.fill")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.clay)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(lang.t("ai.import_headline"))
                .appFont(22, weight: .heavy)
                .foregroundStyle(AppPalette.ink)
            Text(lang.t("ai.import_body"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pasteField: some View {
        TextField(lang.t("ai.import_placeholder"),
                  text: $pasted,
                  axis: .vertical)
            .lineLimit(10...20)
            .padding(14)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onChange(of: pasted) { _, new in
                if new.count > maxChars {
                    pasted = String(new.prefix(maxChars))
                }
            }
    }

    private var helperRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "character.cursor.ibeam")
                .font(.caption2)
                .foregroundStyle(AppPalette.inkSoft)
            Text(String(format: lang.t("ai.import_char_count_format"),
                        pasted.count, maxChars))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(pasted.count >= maxChars
                                 ? AppPalette.alert
                                 : AppPalette.inkSoft)
            Spacer()
        }
    }

    private var saveButton: some View {
        Button(action: { Task { await save() } }) {
            HStack {
                if isSaving { ProgressView().tint(.white) }
                Text(lang.t("ai.import_save_cta"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppPalette.clay)
        .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppPalette.alert)
            Text(text)
                .font(.caption.weight(.semibold))
            Spacer()
        }
        .padding(12)
        .background(AppPalette.alert.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppPalette.alert.opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(lang.t("ai.import_privacy_kicker"), systemImage: "lock.shield.fill")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(lang.t("ai.import_privacy_body"))
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Save

    private func save() async {
        errorMessage = nil
        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let supabaseSession = session.remoteSession else {
            errorMessage = lang.t("ai.error_sign_in_required")
            return
        }
        isSaving = true
        defer { isSaving = false }

        do {
            try await aiClient.saveImportedContext(
                summary: trimmed,
                rawExcerpt: trimmed,
                session: supabaseSession
            )
            savedSuccessfully = true
        } catch {
            errorMessage = aiClient.lastError ?? error.localizedDescription
        }
    }
}
