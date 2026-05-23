import SwiftUI
import AuthenticationServices

/// PaywallView wears two hats and which one is shown is decided by
/// `LaunchOffer.allFeaturesFree`:
///
///   • **Tip jar mode** (launch window, current default) — every Premium
///     feature in the app is already open to all users. The paywall
///     reframes itself as an optional "Support CourtIQ" surface so the
///     StoreKit + Small Business Program plumbing stays warm and anyone
///     who wants to contribute can. Only the yearly product is exposed
///     so the price ladder reads as a single tip amount, not a "plans"
///     selection.
///
///   • **Subscription mode** (default once the launch flag flips) — the
///     traditional benefits + monthly/yearly offer cards. The user-facing
///     copy is structured around what unlocks rather than what supports.
///
/// Both modes preserve Restore Purchases, Privacy, Terms, and Support
/// links per App Store §3.1.2(a). Sign in with Apple is offered as a
/// cross-device sync benefit, never as a purchase gate (App Store §3.1.1).
struct PaywallView: View {
    let source: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager
    @State private var isWorking = false
    @State private var errorMessage: String?
    private let configuration = AppConfiguration.shared

    private var isTipJar: Bool { LaunchOffer.allFeaturesFree }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if isTipJar { whySupportCard } else { benefitsCard }
                offerCards
                legalLinks
                legalNote
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(isTipJar ? lang.t("paywall.tip_title") : lang.t("paywall.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(lang.t("common.done")) {
                    dismiss()
                }
            }
        }
        .alert(lang.t("app.account_issue"), isPresented: Binding(get: {
            errorMessage != nil
        }, set: { newValue in
            if !newValue {
                errorMessage = nil
            }
        })) {
            Button(lang.t("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isTipJar ? lang.t("paywall.tip_headline") : lang.t("paywall.subtitle"))
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(isTipJar ? lang.t("paywall.tip_body") : lang.t("paywall.intro_body"))
                .foregroundStyle(AppPalette.inkSoft)

            // Sign in is OPTIONAL — purchase works as guest via StoreKit's
            // Apple-ID-tied entitlement (no in-app account required, per
            // App Store Review §3.1.1). Signing in only adds cross-device
            // progress sync.
            if !session.isSignedInWithApple {
                VStack(alignment: .leading, spacing: 10) {
                    Text(lang.t("paywall.sign_in_optional"))
                        .font(.subheadline.weight(.semibold))
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        session.handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                }
            }
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Tip-jar mode card

    private var whySupportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("paywall.tip_why"))
                .font(.title3.bold())

            ForEach(tipReasons, id: \.self) { reason in
                Label(reason, systemImage: "heart.fill")
                    .foregroundStyle(AppPalette.ink)
            }
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var tipReasons: [String] {
        [
            lang.t("paywall.tip_reason_1"),
            lang.t("paywall.tip_reason_2"),
            lang.t("paywall.tip_reason_3")
        ]
    }

    // MARK: - Subscription-mode benefits card (legacy)

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("paywall.what_unlocks"))
                .font(.title3.bold())

            ForEach(session.subscriptionManager.premiumBenefits, id: \.self) { benefit in
                Label(benefit, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppPalette.ink)
            }

            if session.subscriptionManager.integrationMode == .productConfigurationMissing {
                Text(lang.t("paywall.products_loading"))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
            }
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Offer cards

    /// In tip-jar mode we only surface the *featured* (yearly) offer so
    /// the screen reads as a single tip choice rather than a plans menu.
    /// Monthly stays defined in `SubscriptionManager.offers` so the IAP
    /// plumbing keeps loading both products from StoreKit unchanged.
    private var visibleOffers: [SubscriptionOffer] {
        let all = session.subscriptionManager.offers
        guard isTipJar else { return all }
        return all.filter { $0.isFeatured }.isEmpty ? Array(all.prefix(1)) : all.filter { $0.isFeatured }
    }

    private var offerCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isTipJar ? lang.t("paywall.tip_action") : lang.t("paywall.choose_plan"))
                .font(.title3.bold())

            ForEach(visibleOffers) { offer in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isTipJar ? lang.t("paywall.tip_offer_title") : offer.title)
                                .font(.headline)
                            Text(isTipJar ? lang.t("paywall.tip_offer_detail") : offer.detail)
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.inkSoft)
                        }
                        Spacer()
                        if !isTipJar && offer.isFeatured {
                            Text(lang.t("paywall.best_value"))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppPalette.clay.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }

                    Text(offer.priceDisplay)
                        .font(.title3.bold())

                    Button {
                        Task {
                            await purchase(offer)
                        }
                    } label: {
                        HStack {
                            if isWorking {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                            Text(buttonLabel)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking || session.subscriptionManager.isPremiumUnlocked && !isTipJar)
                }
                .padding()
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            Button(lang.t("paywall.restore")) {
                Task {
                    isWorking = true
                    defer { isWorking = false }
                    await session.restorePurchases()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isWorking)

            // Manage Subscriptions is only relevant for actual paying
            // subscribers, regardless of tip-jar framing.
            if session.subscriptionManager.entitlementState.isPremium {
                Button(lang.t("paywall.manage")) {
                    session.openManageSubscriptions()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var buttonLabel: String {
        if isTipJar {
            return lang.t("paywall.tip_button")
        }
        return session.subscriptionManager.isPremiumUnlocked
            ? lang.t("paywall.unlocked")
            : lang.t("paywall.continue")
    }

    // MARK: - Legal

    private var legalLinks: some View {
        // Privacy + Terms must always be reachable from the paywall per
        // App Store Review §3.1.2(a). If a hosted URL is configured we
        // open it externally; otherwise we fall back to the in-app
        // LegalDocumentView so the requirement is always satisfied.
        VStack(alignment: .leading, spacing: 10) {
            if let privacyURL = configuration.privacyPolicyURL {
                Link(destination: privacyURL) {
                    Label(lang.t("paywall.privacy"), systemImage: "lock.doc")
                }
            } else {
                NavigationLink {
                    LegalDocumentView(document: .privacy)
                } label: {
                    Label(lang.t("paywall.privacy"), systemImage: "lock.doc")
                }
            }

            if let termsURL = configuration.termsOfUseURL {
                Link(destination: termsURL) {
                    Label(lang.t("paywall.terms"), systemImage: "doc.text")
                }
            } else {
                NavigationLink {
                    LegalDocumentView(document: .terms)
                } label: {
                    Label(lang.t("paywall.terms"), systemImage: "doc.text")
                }
            }

            if let supportURL = configuration.supportURL {
                Link(destination: supportURL) {
                    Label(lang.t("paywall.support"), systemImage: "questionmark.circle")
                }
            } else {
                NavigationLink {
                    LegalDocumentView(document: .support)
                } label: {
                    Label(lang.t("paywall.support"), systemImage: "questionmark.circle")
                }
            }
        }
        .font(.subheadline.weight(.semibold))
    }

    private var legalNote: some View {
        Text(isTipJar ? lang.t("paywall.tip_legal_note") : lang.t("paywall.subscription_note"))
            .font(.footnote)
            .foregroundStyle(AppPalette.inkSoft)
            .padding(.horizontal, 4)
    }

    private func purchase(_ offer: SubscriptionOffer) async {
        isWorking = true
        defer { isWorking = false }

        do {
            try await session.purchase(offer: offer)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
