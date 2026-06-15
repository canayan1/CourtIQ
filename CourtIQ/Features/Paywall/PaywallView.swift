import SwiftUI

/// PaywallView is DropVolley's single hard paywall (no free tier — premium
/// unlocks the whole app). It presents the value of the subscription, two
/// auto-renewing plan cards (Annual featured + pre-selected, Weekly), a
/// single primary CTA that purchases the selected plan, the required
/// auto-renew disclosure, and the Restore / Terms / Privacy footer.
///
/// Compliance (App Store Review §3.1.1 / §3.1.2):
/// - Honest value recap (no fabricated user counts or star ratings).
/// - Price (`priceDisplay`) is the most prominent pricing element.
/// - Trial copy is baked into the Annual card — no separate trial toggle.
/// - Auto-renew + cancel disclosure shown above the CTA.
/// - Restore Purchases, Terms of Use, Privacy Policy always reachable.
///
/// When StoreKit products are not loaded (`.productConfigurationMissing` —
/// e.g. App Review before products are "Ready to Submit") the screen shows
/// a graceful loading state instead of broken/empty price cards.
struct PaywallView: View {
    let source: String
    /// When false (the hard-paywall gate), the dismiss/"Done" control is
    /// hidden so the user cannot bypass the wall without subscribing.
    var allowsDismiss: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager

    @State private var selectedOfferID: String?
    @State private var isWorking = false
    @State private var errorMessage: String?

    private let configuration = AppConfiguration.shared

    private func t(_ en: String, _ tr: String) -> String {
        lang.language == .turkish ? tr : en
    }

    private var manager: SubscriptionManager { session.subscriptionManager }
    private var offers: [SubscriptionOffer] { manager.offers }
    private var productsReady: Bool { manager.integrationMode == .storeKitDirect }

    private var selectedOffer: SubscriptionOffer? {
        if let id = selectedOfferID, let match = offers.first(where: { $0.id == id }) {
            return match
        }
        // Default to the featured (Annual) plan, falling back to the first.
        return offers.first(where: { $0.isFeatured }) ?? offers.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                benefitsCard
                credibilityLine

                if productsReady {
                    planCards
                    primaryCTA
                    disclosureLine
                } else {
                    loadingState
                }

                footerRow
#if DEBUG
                Button(t("Dev: enter app (debug only)", "Dev: uygulamaya gir (sadece debug)")) {
                    manager.debugGrantPremium()
                }
                .font(.caption2)
                .foregroundStyle(AppPalette.inkSoft.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
#endif
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(t("Go Premium", "Premium’a Geç"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if allowsDismiss {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("Done", "Bitti")) { dismiss() }
                }
            }
        }
        .alert(t("Account issue", "Hesap sorunu"), isPresented: Binding(get: {
            errorMessage != nil
        }, set: { newValue in
            if !newValue { errorMessage = nil }
        })) {
            Button(t("OK", "Tamam"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            // Re-load StoreKit products every time the paywall opens so a
            // failed/cold initial load (or a just-accepted Paid Apps
            // Agreement) doesn't leave the purchase buttons non-functional.
            await manager.loadOfferings()
            if selectedOfferID == nil {
                selectedOfferID = selectedOffer?.id
            }
        }
    }

    // MARK: - 1. Headline

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 60, height: 60)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(t("Unlock your full tennis game", "Tüm tenis oyununu aç"))
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(t(
                "Every drill, quiz, training plan, and your AI coach — all in one membership.",
                "Tüm drilller, sınavlar, antrenman planları ve AI koçun — tek üyelikte."
            ))
            .foregroundStyle(.white.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Marquee paywall hero: duotone PhotoHero with white foreground.
        .brandedPhoto("PhotoHero", scrim: .hero, cornerRadius: 24)
    }

    // MARK: - 2. Value recap

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(manager.premiumBenefits, id: \.self) { benefit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.moss)
                    Text(benefit)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - 3. Credibility line (honest, no fabricated metrics)

    private var credibilityLine: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppPalette.mossDeep)
            Text(t(
                "Evidence-based — built on USTA & ITF coaching frameworks",
                "Kanıta dayalı — USTA & ITF antrenörlük çerçeveleriyle"
            ))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppPalette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 4. Plan cards

    private var planCards: some View {
        VStack(spacing: 14) {
            ForEach(offers) { offer in
                planCard(for: offer)
            }
        }
    }

    private func planCard(for offer: SubscriptionOffer) -> some View {
        let isSelected = selectedOffer?.id == offer.id
        return Button {
            selectedOfferID = offer.id
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(offer.title)
                            .font(.headline)
                            .foregroundStyle(AppPalette.ink)
                        Text(offer.detail)
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    selectionIndicator(isSelected: isSelected)
                }

                if offer.isFeatured {
                    HStack(spacing: 8) {
                        chip(t("Best Value", "En İyi Değer"), filled: true)
                        if let save = offer.saveBadge {
                            chip(save, filled: false)
                        }
                    }
                }

                // Price is the most prominent pricing element.
                Text(offer.priceDisplay)
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(AppPalette.ink)

                if offer.isFeatured, let perWeek = offer.perWeekText {
                    Text(perWeek)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.clay)
                }

                if offer.isFeatured, let trial = offer.trialText {
                    Text(trial)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppPalette.clay.opacity(0.08) : AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? AppPalette.clay : AppPalette.sand,
                            lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(isSelected ? AppPalette.clay : AppPalette.sand)
    }

    private func chip(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(filled ? AppPalette.clay : AppPalette.clay.opacity(0.14))
            .foregroundStyle(filled ? Color.white : AppPalette.clay)
            .clipShape(Capsule())
    }

    // MARK: - 5. Primary CTA

    private var primaryCTA: some View {
        Button {
            guard let offer = selectedOffer else { return }
            Task { await purchase(offer) }
        } label: {
            HStack {
                if isWorking {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text(ctaLabel)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppPalette.clay)
        .disabled(isWorking || selectedOffer == nil)
    }

    private var ctaLabel: String {
        if selectedOffer?.trialText != nil {
            return t("Start my 3 free days", "3 günümü ücretsiz başlat")
        }
        return t("Continue", "Devam et")
    }

    // MARK: - 6. Disclosure line (auto-renew + cancel)

    private var disclosureLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let trial = selectedOffer?.trialText {
                Text(trial)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(t(
                "Auto-renews unless cancelled at least 24 hours before the period ends. Manage or cancel anytime in Settings.",
                "Dönem bitmeden en az 24 saat önce iptal edilmezse otomatik yenilenir. Ayarlar’dan istediğin zaman yönet veya iptal et."
            ))
            .font(.footnote)
            .foregroundStyle(AppPalette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Graceful state when products aren't loaded

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView().progressViewStyle(.circular)
                Text(t("Loading subscription options…", "Abonelik seçenekleri yükleniyor…"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
            }
            Text(t(
                "Hang tight — fetching current pricing from the App Store. If this persists, check your connection and try again.",
                "Bir saniye — App Store’dan güncel fiyatlar alınıyor. Sürerse bağlantını kontrol edip tekrar dene."
            ))
            .font(.footnote)
            .foregroundStyle(AppPalette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - 7. Footer row

    private var footerRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                footerButton(t("Restore Purchases", "Satın Almaları Geri Yükle")) {
                    Task { await restore() }
                }
                footerDivider
                footerButton(t("Terms of Use", "Kullanım Şartları")) {
                    openLink(configuration.termsOfUseURL, fallback: .terms)
                }
                footerDivider
                footerButton(t("Privacy Policy", "Gizlilik Politikası")) {
                    openLink(configuration.privacyPolicyURL, fallback: .privacy)
                }
            }
            .sheet(item: $legalFallback) { document in
                NavigationStack {
                    LegalDocumentView(document: document)
                }
            }
            .font(.footnote.weight(.semibold))

            if manager.entitlementState.isPremium {
                Button(t("Manage Subscription", "Aboneliği Yönet")) {
                    session.openManageSubscriptions()
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppPalette.clay)
                .frame(maxWidth: .infinity)
        }
        .disabled(isWorking)
    }

    private var footerDivider: some View {
        Text("·")
            .foregroundStyle(AppPalette.inkSoft)
            .padding(.horizontal, 2)
    }

    // MARK: - Navigation fallback for legal links

    @State private var legalFallback: LegalDocument?

    private func openLink(_ url: URL?, fallback: LegalDocument) {
        if let url {
            openURL(url)
        } else {
            legalFallback = fallback
        }
    }

    // MARK: - Actions

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

    private func restore() async {
        isWorking = true
        defer { isWorking = false }
        await session.restorePurchases()
        if manager.entitlementState.isPremium {
            dismiss()
        }
    }
}
