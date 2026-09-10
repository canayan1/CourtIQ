import Foundation
import Combine
import StoreKit

/// Owns the user's coach-review orders: the consumable purchase, the upload,
/// and the local cache that keeps the status card rendering offline. Follows
/// the app's standard manager shape (singleton + @Published + UserDefaults
/// JSON, best-effort remote sync).
///
/// The one rule everything here serves: **a charged player always ends up
/// with an order or with their money back — never with neither.** A
/// consumable purchase is finished only after the server has stored the
/// order; until then the transaction stays unfinished, the clip stays on disk
/// under `Application Support/CoachReview`, and `resume(session:)` retries on
/// every launch and foreground. The generic transaction listener in
/// `UserSessionManager` skips this product for exactly that reason.
@MainActor
final class CoachReviewManager: ObservableObject {
    static let shared = CoachReviewManager()

    @Published private(set) var orders: [CoachReviewOrder] = []
    @Published private(set) var deliverables: [String: CoachReviewDeliverable] = [:]
    /// Paid-but-not-yet-ordered submissions waiting for a retry, oldest first.
    @Published private(set) var pending: [PendingSubmission] = []
    @Published private(set) var isSubmitting = false
    /// True once StoreKit confirms the consumable exists in the current
    /// storefront. Until then the app must NOT offer a purchase — Apple's
    /// first-consumable rule means the product can be approved later than the
    /// build that ships this screen, and a dead Buy button is both bad UX and
    /// a 2.1 rejection risk.
    @Published private(set) var productAvailable = false
    /// The storefront's own price string ("$19.99", "19,99 €") — the only
    /// price the UI is allowed to print.
    @Published private(set) var productDisplayPrice: String?

    /// A submission between "Apple charged the card" and "the server has the
    /// order". Survives relaunch; the clip it points at lives in the durable
    /// directory, not the temp folder the picker handed us.
    struct PendingSubmission: Codable, Identifiable, Hashable {
        let id: String
        var transactionID: String?
        var transactionJWS: String?
        /// File name inside `clipDirectory`. Nil means we hold a payment but
        /// no clip — the app data was wiped after the charge, or Ask-to-Buy
        /// approved a purchase the app never saw complete.
        var clipFileName: String?
        var stroke: String
        var handedness: String?
        var note: String?
        var reviewLanguage: String
        var createdAt: Date
        var lastError: String?

        var isPaid: Bool { transactionID != nil }
        var hasClip: Bool { clipFileName != nil }
    }

    private let service = CoachReviewService()
    private let defaults = UserDefaults.standard
    private let ordersKey = "CourtIQ.CoachReview.Orders"
    private let deliverablesKey = "CourtIQ.CoachReview.Deliverables"
    private let pendingKey = "CourtIQ.CoachReview.Pending"
    private var configuration: AppConfiguration { .shared }

    private init() {
        orders = Self.decode([CoachReviewOrder].self, from: defaults, key: ordersKey) ?? []
        deliverables = Self.decode([String: CoachReviewDeliverable].self, from: defaults, key: deliverablesKey) ?? [:]
        pending = Self.decode([PendingSubmission].self, from: defaults, key: pendingKey) ?? []
    }

    /// Asks StoreKit whether the review credit is purchasable right now.
    /// Cheap, cached by StoreKit, safe to call on every appearance.
    func refreshProductAvailability(productID: String) async {
        let products = try? await Product.products(for: [productID])
        productAvailable = !(products ?? []).isEmpty
        productDisplayPrice = products?.first?.displayPrice
    }

    // MARK: Derived

    /// The order the status card should surface: the newest one still open,
    /// otherwise the newest delivered-but-unseen review.
    var activeOrder: CoachReviewOrder? {
        orders.first { $0.status.isOpen } ?? orders.first { $0.status == .delivered }
    }

    var hasAnyOrder: Bool { !orders.isEmpty }
    /// True while anything needs the network: an unsent paid clip, an open
    /// order, or a delivered order whose report has not been pulled yet.
    var needsSync: Bool {
        !pending.isEmpty
            || orders.contains { $0.status.isOpen }
            || orders.contains { $0.status == .delivered && deliverables[$0.id] == nil }
    }

    func deliverable(for orderID: String) -> CoachReviewDeliverable? { deliverables[orderID] }

    // MARK: Purchase + submit

    enum SubmitError: LocalizedError {
        case productUnavailable
        case purchaseCancelled
        case purchasePending
        case verificationFailed
        case upload(String)

        var errorDescription: String? {
            switch self {
            case .productUnavailable: return "Coach review isn't available right now."
            case .purchaseCancelled:  return nil          // silent — user chose to stop
            case .purchasePending:    return "Your purchase is pending approval."
            case .verificationFailed: return "That purchase couldn't be verified."
            case .upload(let message): return message
            }
        }
    }

    /// Buys one review credit and submits the clip.
    ///
    /// Order of operations is the whole safety story: the clip is copied
    /// somewhere durable and a pending record is written BEFORE the App Store
    /// sheet opens, so a crash or a dropped connection anywhere after the
    /// charge leaves something on disk that `resume` can finish.
    ///
    /// If a payment is already on file without a clip (see
    /// `PendingSubmission.clipFileName`), this attaches the clip to it and
    /// does NOT open the App Store sheet — the player is never charged twice.
    func purchaseAndSubmit(
        videoURL: URL,
        stroke: SwingStroke,
        handedness: SwingHandedness?,
        note: String?,
        reviewLanguage: String,
        session: SupabaseSession,
        productID: String
    ) async throws {
        isSubmitting = true
        defer { isSubmitting = false }

        // A paid-but-clipless record takes precedence over a new purchase.
        if let orphanIndex = pending.firstIndex(where: { $0.isPaid && !$0.hasClip }) {
            let fileName = try Self.copyClipToDurableStorage(videoURL)
            pending[orphanIndex].clipFileName = fileName
            pending[orphanIndex].stroke = stroke.rawValue
            pending[orphanIndex].handedness = handedness?.rawValue
            pending[orphanIndex].note = note
            pending[orphanIndex].reviewLanguage = reviewLanguage
            persist()
            try await submit(pending[orphanIndex], session: session)
            return
        }

        let products = try await Product.products(for: [productID])
        guard let product = products.first else { throw SubmitError.productUnavailable }

        let fileName = try Self.copyClipToDurableStorage(videoURL)
        var record = PendingSubmission(
            id: UUID().uuidString,
            transactionID: nil, transactionJWS: nil,
            clipFileName: fileName,
            stroke: stroke.rawValue, handedness: handedness?.rawValue,
            note: note, reviewLanguage: reviewLanguage,
            createdAt: Date(), lastError: nil)
        pending.append(record)
        persist()

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            removePending(record.id)
            throw error
        }

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                // Unverifiable = we do not treat it as paid. The record stays
                // unpaid; a later `Transaction.unfinished` pass can still pair it.
                throw SubmitError.verificationFailed
            }
            record.transactionID = String(transaction.id)
            record.transactionJWS = verification.jwsRepresentation
            replacePending(record)
            try await submit(record, session: session)
        case .userCancelled:
            removePending(record.id)
            throw SubmitError.purchaseCancelled
        case .pending:
            // Ask to Buy. The charge, if approved, surfaces later through
            // `Transaction.unfinished`; `resume` pairs it with this clip.
            throw SubmitError.purchasePending
        @unknown default:
            removePending(record.id)
            throw SubmitError.verificationFailed
        }
    }

    /// Sends one paid record to the server. Only a stored order finishes the
    /// transaction; any failure leaves both the record and the transaction in
    /// place for the next `resume`.
    private func submit(_ record: PendingSubmission, session: SupabaseSession) async throws {
        guard record.isPaid, let fileName = record.clipFileName else { return }
        let clipURL = Self.clipDirectory.appendingPathComponent(fileName)
        do {
            let created = try await service.createOrder(
                videoURL: clipURL,
                stroke: record.stroke,
                handedness: record.handedness,
                note: record.note,
                reviewLanguage: record.reviewLanguage,
                transactionID: record.transactionID,
                transactionJWS: record.transactionJWS,
                session: session
            )
            // Only finish AFTER the order is safely stored, so a failed upload
            // leaves the transaction unfinished (StoreKit re-delivers it) and
            // the player never pays for nothing.
            await Self.finishTransaction(id: record.transactionID)

            let order = CoachReviewOrder(
                id: created.orderId,
                status: .submitted,
                stroke: record.stroke,
                handedness: record.handedness,
                note: record.note,
                createdAt: Date(),
                slaDueAt: ISO8601DateFormatter.supabaseFractional.date(from: created.slaDueAt)
                    ?? ISO8601DateFormatter.supabasePlain.date(from: created.slaDueAt)
                    ?? Date().addingTimeInterval(72 * 3600),
                deliveredAt: nil
            )
            orders.insert(order, at: 0)
            removePending(record.id)
            try? FileManager.default.removeItem(at: clipURL)
            persist()
            AppAnalytics.shared.log(AnalyticsEvent.coachReviewOrdered, ["stroke": record.stroke])
        } catch {
            // Typed server outcomes are stored as localisation keys so the
            // card and the alert can say them in the player's language.
            let message: String
            switch error as? CoachReviewService.ServiceError {
            case .capacityFull?:     message = "coachreview.capacity_full"
            case .purchaseRejected?: message = "coachreview.purchase_rejected"
            default:                 message = error.localizedDescription
            }
            var failed = record
            failed.lastError = message
            replacePending(failed)
            throw SubmitError.upload(message)
        }
    }

    // MARK: - Resume

    /// Finishes whatever a previous run left half-done. Called on launch and
    /// on every return to the foreground (`syncIfNeeded`), and from the
    /// status card's retry button.
    ///
    /// 1. Every unfinished coach-review transaction StoreKit still holds is
    ///    matched to a pending record: by id, else to an unpaid record that
    ///    has a clip (Ask-to-Buy approved after the fact), else a new
    ///    clip-less record is created so the payment is never invisible.
    /// 2. Every paid record with a clip is submitted.
    /// 3. Orders and any newly delivered reports are pulled.
    func resume(session: SupabaseSession) async {
        let coachProduct = configuration.coachReviewProductID
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result,
                  transaction.productID == coachProduct else { continue }
            let id = String(transaction.id)
            if pending.contains(where: { $0.transactionID == id }) { continue }
            if let unpaid = pending.firstIndex(where: { !$0.isPaid && $0.hasClip }) {
                pending[unpaid].transactionID = id
                pending[unpaid].transactionJWS = result.jwsRepresentation
            } else {
                pending.append(PendingSubmission(
                    id: UUID().uuidString,
                    transactionID: id, transactionJWS: result.jwsRepresentation,
                    clipFileName: nil,
                    stroke: SwingStroke.forehand.rawValue, handedness: nil,
                    note: nil, reviewLanguage: "en",
                    createdAt: transaction.purchaseDate, lastError: nil))
            }
        }
        persist()

        for record in pending where record.isPaid && record.hasClip {
            try? await submit(record, session: session)
        }
        await refresh(session: session)
    }

    /// Cheap gate for the foreground hook: does nothing for the vast
    /// majority of players who never bought a review.
    func syncIfNeeded(ensureSession: () async throws -> SupabaseSession) async {
        var hasUnfinished = false
        for await result in Transaction.unfinished {
            if case .verified(let t) = result, t.productID == configuration.coachReviewProductID {
                hasUnfinished = true; break
            }
        }
        guard needsSync || hasUnfinished else { return }
        guard let session = try? await ensureSession() else { return }
        await resume(session: session)
    }

    // MARK: - Sync

    /// Refreshes statuses + pulls any newly delivered review. Best effort:
    /// a network failure leaves the cached view intact.
    func refresh(session: SupabaseSession) async {
        guard let remote = try? await service.fetchOrders(session: session) else { return }
        orders = remote
        persist()

        for order in remote where order.status == .delivered && deliverables[order.id] == nil {
            if let deliverable = try? await service.fetchDeliverable(orderID: order.id, session: session) {
                deliverables[order.id] = deliverable
                persist()
            }
        }
    }

    /// A short-lived playable URL for a delivered voice note. Minted through
    /// the user's own session, so RLS decides — the app never holds a
    /// permanent link.
    func voiceURL(for deliverable: CoachReviewDeliverable, session: SupabaseSession) async -> URL? {
        guard let path = deliverable.voicePath else { return nil }
        return try? await service.signedURL(forObject: path, session: session)
    }

    // MARK: - Internals

    private static let clipDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("CoachReview", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// The picker hands us a temp-folder URL the system may reclaim at any
    /// time; a paid clip has to outlive the process.
    private static func copyClipToDurableStorage(_ source: URL) throws -> String {
        let name = UUID().uuidString + "." + (source.pathExtension.isEmpty ? "mp4" : source.pathExtension)
        let dest = clipDirectory.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: dest)
        return name
    }

    private static func finishTransaction(id: String?) async {
        guard let id else { return }
        for await result in Transaction.unfinished {
            if case .verified(let t) = result, String(t.id) == id {
                await t.finish()
                return
            }
        }
    }

    private func replacePending(_ record: PendingSubmission) {
        if let i = pending.firstIndex(where: { $0.id == record.id }) { pending[i] = record } else { pending.append(record) }
        persist()
    }

    private func removePending(_ id: String) {
        if let i = pending.firstIndex(where: { $0.id == id }) {
            if let file = pending[i].clipFileName {
                try? FileManager.default.removeItem(at: Self.clipDirectory.appendingPathComponent(file))
            }
            pending.remove(at: i)
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(orders) { defaults.set(data, forKey: ordersKey) }
        if let data = try? JSONEncoder().encode(deliverables) { defaults.set(data, forKey: deliverablesKey) }
        if let data = try? JSONEncoder().encode(pending) { defaults.set(data, forKey: pendingKey) }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
