import SwiftUI

/// The one card a paying player needs after the App Store sheet closes.
/// Three states, in priority order:
///
/// 1. **Pending** — Apple charged, the server has no order yet. Shows the
///    retry button and the last error; if the payment has no clip attached,
///    tells the player to send one and that they will not be charged again.
/// 2. **Open** — the order exists; shows the status and the hours left on
///    the 72 h clock.
/// 3. **Delivered** — opens the review.
///
/// Renders nothing for the vast majority of players who never bought one.
struct CoachReviewStatusCard: View {
    let ensureSession: () async throws -> SupabaseSession

    @ObservedObject private var manager = CoachReviewManager.shared
    @EnvironmentObject private var lang: LanguageManager
    @State private var showDeliverable = false
    @State private var isRetrying = false
    @State private var showReuploadPicker = false
    @State private var reuploadError: String?

    var body: some View {
        Group {
            if let record = manager.pending.first {
                pendingCard(record)
            } else if let order = manager.activeOrder, order.status.isWaitingOnPlayer {
                reuploadCard(order)
            } else if let order = manager.activeOrder {
                orderCard(order)
            }
        }
        .task { await manager.syncIfNeeded(ensureSession: ensureSession) }
    }

    // MARK: Pending

    private func pendingCard(_ record: CoachReviewManager.PendingSubmission) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: record.hasClip ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppPalette.clay)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(lang.t("coachreview.order_eyebrow"), tint: AppPalette.clayText)
                    Text(lang.t(record.hasClip ? "coachreview.pending_title" : "coachreview.orphan_title"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                    Text(lang.t(record.hasClip ? "coachreview.pending_body" : "coachreview.orphan_body"))
                        .font(.footnote)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if let error = record.lastError, !error.isEmpty {
                        Text(error.hasPrefix("coachreview.") ? lang.t(error) : error)
                            .font(.caption)
                            .foregroundStyle(AppPalette.clayText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if record.hasClip {
                Button {
                    Haptics.tap()
                    Task {
                        isRetrying = true
                        defer { isRetrying = false }
                        if let session = try? await ensureSession() {
                            await manager.resume(session: session)
                        }
                    }
                } label: {
                    HStack {
                        if isRetrying { ProgressView().tint(.white) }
                        Text(isRetrying ? lang.t("coachreview.sending") : lang.t("coachreview.pending_retry"))
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppPalette.clay, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressableCardStyle())
                .disabled(isRetrying)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.goldTint.opacity(0.55))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppPalette.gold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Coach sent it back

    /// The coach could not open the clip. Same paid order, new clip, no
    /// second charge; the 72-hour clock restarts when it lands.
    private func reuploadCard(_ order: CoachReviewOrder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppPalette.clay)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(lang.t("coachreview.order_eyebrow"), tint: AppPalette.clayText)
                    Text(lang.t("coachreview.reupload_title"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                    Text(lang.t("coachreview.reupload_body"))
                        .font(.footnote)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if let message = order.coachMessage, !message.isEmpty {
                        Text("“\(message)”")
                            .font(.footnote.italic())
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let reuploadError {
                        Text(reuploadError)
                            .font(.caption)
                            .foregroundStyle(AppPalette.clayText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Button {
                Haptics.tap()
                showReuploadPicker = true
            } label: {
                HStack {
                    if manager.isSubmitting { ProgressView().tint(.white) }
                    Text(manager.isSubmitting ? lang.t("coachreview.sending") : lang.t("coachreview.reupload_cta"))
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppPalette.clay, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PressableCardStyle())
            .disabled(manager.isSubmitting)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.goldTint.opacity(0.55))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppPalette.gold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(isPresented: $showReuploadPicker) {
            VideoPicker(sourceType: .photoLibrary) { url in
                showReuploadPicker = false
                guard let url else { return }
                Task {
                    do {
                        let session = try await ensureSession()
                        try await manager.reupload(orderID: order.id, videoURL: url, session: session)
                        reuploadError = nil
                        Haptics.success()
                    } catch {
                        reuploadError = error.localizedDescription
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Open / delivered

    private func orderCard(_ order: CoachReviewOrder) -> some View {
        let delivered = order.status == .delivered
        let report = manager.deliverable(for: order.id)
        return Button {
            Haptics.tap()
            if delivered, report != nil {
                showDeliverable = true
            } else {
                Task { if let s = try? await ensureSession() { await manager.refresh(session: s) } }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: delivered ? "envelope.open.fill" : "person.wave.2.fill")
                    .font(.title3)
                    .foregroundStyle(delivered ? AppPalette.moss : AppPalette.goldText)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(lang.t("coachreview.order_eyebrow"), tint: delivered ? AppPalette.mossDeep : AppPalette.goldText)
                    Text(delivered ? lang.t("coachreview.ready_title") : lang.t(order.status.shortLabelKey))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                    if delivered {
                        Text(lang.t("coachreview.open_review"))
                            .font(.footnote)
                            .foregroundStyle(AppPalette.inkSoft)
                    } else if let hours = order.hoursRemaining {
                        Text(String(format: lang.t("coachreview.hours_left_fmt"), hours))
                            .font(.footnote)
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((delivered ? AppPalette.mossTint : AppPalette.goldTint).opacity(0.55))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke((delivered ? AppPalette.moss : AppPalette.gold).opacity(0.4), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .navigationDestination(isPresented: $showDeliverable) {
            if let report {
                CoachReviewDeliverableView(order: order, deliverable: report, ensureSession: ensureSession)
            }
        }
    }
}
