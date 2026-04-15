import Foundation

struct AppConfiguration {
    let appName = "CourtIQ"
    let privacyPolicyURL: URL?
    let termsOfUseURL: URL?
    let supportURL: URL?
    let supabaseURL: URL?
    let supabaseAnonKey: String?
    let revenueCatAPIKey: String?
    let monthlyProductID: String
    let yearlyProductID: String
    let premiumEntitlementID: String

    static let shared = AppConfiguration()

    private init(bundle: Bundle = .main) {
        privacyPolicyURL = Self.urlValue(for: "COURTIQ_PRIVACY_URL", bundle: bundle)
        termsOfUseURL = Self.urlValue(for: "COURTIQ_TERMS_URL", bundle: bundle)
        supportURL = Self.urlValue(for: "COURTIQ_SUPPORT_URL", bundle: bundle)
        supabaseURL = Self.urlValue(for: "COURTIQ_SUPABASE_URL", bundle: bundle)
        supabaseAnonKey = Self.stringValue(for: "COURTIQ_SUPABASE_ANON_KEY", bundle: bundle)
        revenueCatAPIKey = Self.stringValue(for: "COURTIQ_REVENUECAT_API_KEY", bundle: bundle)
        monthlyProductID = Self.stringValue(for: "COURTIQ_MONTHLY_PRODUCT_ID", bundle: bundle) ?? "com.courtiq.premium.monthly"
        yearlyProductID = Self.stringValue(for: "COURTIQ_YEARLY_PRODUCT_ID", bundle: bundle) ?? "com.courtiq.premium.yearly"
        premiumEntitlementID = Self.stringValue(for: "COURTIQ_PREMIUM_ENTITLEMENT_ID", bundle: bundle) ?? "premium_all_access"
    }

    var hasRemoteSyncConfiguration: Bool {
        supabaseURL != nil && !(supabaseAnonKey?.isEmpty ?? true)
    }

    var hasRevenueCatConfiguration: Bool {
        !(revenueCatAPIKey?.isEmpty ?? true)
    }

    private static func stringValue(for key: String, bundle: Bundle) -> String? {
        bundle.object(forInfoDictionaryKey: key) as? String
    }

    private static func urlValue(for key: String, bundle: Bundle) -> URL? {
        guard let value = stringValue(for: key, bundle: bundle), !value.isEmpty else {
            return nil
        }
        return URL(string: value)
    }
}
