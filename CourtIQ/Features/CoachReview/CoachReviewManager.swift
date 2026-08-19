import Foundation
import Combine
import StoreKit

/// Owns the user's coach-review orders: the consumable purchase, the upload,
/// and the local cache that keeps the status card rendering offline. Follows
/// the app's standard manager shape (singleton + @Published + UserDefaults
/// JSON, best-effort remote sync).
@MainActor
final class CoachReviewManager: ObservableObject {
    static let shared = CoachReviewManager()

    @Published private(set) var orders: [CoachReviewOrder] = []
    @Published private(set) var deliverables: [String: CoachReviewDeliverable] = [:]
    @Published private(set) var isSubmitting = false

    private let service = CoachReviewService()
    private let defaults = UserDefaults.standard
    private let ordersKey = "CourtIQ.CoachReview.Orders"
    private let deliverablesKey = "CourtIQ.CoachReview.Deliverables"

    private init() {
        orders = Self.decode([CoachReviewOrder].self, from: defaults, key: ordersKey) ?? []
        deliverables = Self.decode([String: CoachReviewDeliverable].self, from: defaults, key: deliverablesKey) ?? [:]
    }

    // MARK: Derived

    /// The order the status card should surface: the newest one still open,
    /// otherwise the newest delivered-but-unseen review.
    var activeOrder: CoachReviewOrder? {
        orders.first { $0.status.isOpen } ?? orders.first { $0.status == .delivered }
    }

    var hasAnyOrder: Bool { !orders.isEmpty }

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

    /// Buys one review credit and immediately submits the clip. The credit is
    /// consumed by the submission itself — there is no floating balance to
    /// lose, and the transaction is only finished once the order exists.
    func purchaseAndSubmit(
        videoURL: URL,
        stroke: SwingStroke,
        handedness: SwingHandedness?,
        note: String?,
        session: SupabaseSession,
        productID: String
    ) async throws {
        isSubmitting = true
        defer { isSubmitting = false }

        let products = try await Product.products(for: [productID])
        guard let product = products.first else { throw SubmitError.productUnavailable }

        let result = try await product.purchase()
        let transaction: StoreKit.Transaction
        switch result {
        case .success(let verification):
            guard case .verified(let verified) = verification else { throw SubmitError.verificationFailed }
            transaction = verified
        case .userCancelled: throw SubmitError.purchaseCancelled
        case .pending:       throw SubmitError.purchasePending
        @unknown default:    throw SubmitError.verificationFailed
        }

        do {
            let created = try await service.createOrder(
                videoURL: videoURL,
                stroke: stroke,
                handedness: handedness,
                note: note,
                transactionID: String(transaction.id),
                session: session
            )
            // Only finish AFTER the order is safely stored, so a failed upload
            // leaves the transaction unfinished (StoreKit re-delivers it) and
            // the player never pays for nothing.
            await transaction.finish()

            let order = CoachReviewOrder(
                id: created.orderId,
                status: .submitted,
                stroke: stroke.rawValue,
                handedness: handedness?.rawValue,
                note: note,
                createdAt: Date(),
                slaDueAt: ISO8601DateFormatter.supabaseFractional.date(from: created.slaDueAt)
                    ?? ISO8601DateFormatter.supabasePlain.date(from: created.slaDueAt)
                    ?? Date().addingTimeInterval(72 * 3600),
                deliveredAt: nil
            )
            orders.insert(order, at: 0)
            persist()
            AppAnalytics.shared.log(AnalyticsEvent.coachReviewOrdered, ["stroke": stroke.rawValue])
        } catch {
            throw SubmitError.upload(error.localizedDescription)
        }
    }

    // MARK: Sync

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

    // MARK: - Internals

    private func persist() {
        if let data = try? JSONEncoder().encode(orders) {
            defaults.set(data, forKey: ordersKey)
        }
        if let data = try? JSONEncoder().encode(deliverables) {
            defaults.set(data, forKey: deliverablesKey)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
