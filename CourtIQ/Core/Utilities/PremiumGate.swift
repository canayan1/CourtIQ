import Foundation
import Observation
import StoreKit

@Observable
final class PremiumGate {
    private(set) var isPremium: Bool = false
    private(set) var isLoading: Bool = false

    static let monthlyProductID = "com.courtiq.premium.monthly"
    static let annualProductID  = "com.courtiq.premium.annual"

    var freeQuizDailyLimit: Int { 3 }
    var freeProgressHistoryDays: Int { 7 }

    func canAccessQuiz(todayCount: Int) -> Bool {
        isPremium || todayCount < freeQuizDailyLimit
    }

    func canAccessTipArchive() -> Bool { isPremium }
    func canAccessFullProgressHistory() -> Bool { isPremium }
    func canAccessPremiumExplanations() -> Bool { isPremium }

    func loadPurchasedProducts() async {
        isLoading = true
        defer { isLoading = false }
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable {
                isPremium = true
                return
            }
        }
        isPremium = false
    }

    func purchase(productID: String) async throws {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else { throw AppError.productNotFound }
        let result = try await product.purchase()
        if case .success(let verification) = result,
           case .verified = verification {
            isPremium = true
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await loadPurchasedProducts()
    }
}
