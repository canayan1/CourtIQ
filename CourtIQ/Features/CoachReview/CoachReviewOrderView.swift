import SwiftUI

/// The paid order flow: consent (a HUMAN will watch this) → optional note →
/// buy + upload. Deliberately one screen, ≤5-word primary lines; the legal
/// detail lives one layer down in the consent block, exactly as
/// docs/COACH-REVIEW-POLICY.md §2 specifies.
struct CoachReviewOrderView: View {
    let videoURL: URL
    let stroke: SwingStroke
    let handedness: SwingHandedness?
    /// Supplies a fresh Supabase session (same closure the swing flow uses).
    let ensureSession: () async throws -> SupabaseSession

    @EnvironmentObject private var lang: LanguageManager
    @ObservedObject private var manager = CoachReviewManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    @State private var consented = false
    @State private var isAdult = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var didSubmit = false

    private var canOrder: Bool { consented && isAdult && !manager.isSubmitting }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                whatYouGet
                noteField
                consentBlock
                orderButton
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("coachreview.order_title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(lang.t("coachreview.error_title"), isPresented: $showError) {
            Button(lang.t("coachreview.done")) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .navigationDestination(isPresented: $didSubmit) {
            CoachReviewSubmittedView()
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(lang.t("coachreview.card_eyebrow"))
            Text(lang.t("coachreview.order_headline"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.ink)
            Text(lang.t("coachreview.coach_line"))
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var whatYouGet: some View {
        VStack(alignment: .leading, spacing: 12) {
            bullet("waveform", lang.t("coachreview.point1"))
            bullet("list.bullet.rectangle", lang.t("coachreview.point2"))
            bullet("target", lang.t("coachreview.point3"))
            bullet("clock.badge.checkmark", lang.t("coachreview.point4"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("coachreview.note_label"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
            TextField(lang.t("coachreview.note_placeholder"), text: $note, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(AppPalette.parchment, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    /// The honest disclosure: who watches, what they can't do, how long it
    /// lives, and the third-party/18+ attestations.
    private var consentBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(AppPalette.moss)
                Text(lang.t("coachreview.privacy"))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle(isOn: $consented) {
                Text(lang.t("coachreview.consent_human"))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.ink)
            }
            Toggle(isOn: $isAdult) {
                Text(lang.t("coachreview.consent_adult"))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.ink)
            }
        }
        .tint(AppPalette.clay)
        .padding(16)
        .background(AppPalette.mossTint.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
    }

    private var orderButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if manager.isSubmitting { ProgressView().tint(.white) }
                Text(manager.isSubmitting ? lang.t("coachreview.sending") : lang.t("coachreview.order_cta"))
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canOrder ? AppPalette.clay : AppPalette.sand,
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableCardStyle())
        .disabled(!canOrder)
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.clay)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Submit

    private func submit() async {
        do {
            let session = try await ensureSession()
            try await manager.purchaseAndSubmit(
                videoURL: videoURL,
                stroke: stroke,
                handedness: handedness,
                note: note.isEmpty ? nil : note,
                session: session,
                productID: AppConfiguration.shared.coachReviewProductID
            )
            Haptics.celebrate()
            didSubmit = true
        } catch CoachReviewManager.SubmitError.purchaseCancelled {
            // User backed out of the sheet — no error to show.
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

/// Post-purchase confirmation — sets the 72h expectation and gets out of the way.
struct CoachReviewSubmittedView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "paperplane.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppPalette.clay)
            Text(lang.t("coachreview.sent_title"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.ink)
            Text(lang.t("coachreview.sent_body"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Text(lang.t("coachreview.done"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppPalette.clay, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableCardStyle())
        }
        .padding(24)
        .background(AppPalette.cream)
        .navigationBarBackButtonHidden(true)
    }
}
