import SwiftUI

/// PaywallView is DropVolley's subscription upsell, shown contextually when a
/// free user hits a premium gate (AI Coach, swing analysis beyond the free
/// taste, the full tip/quiz archive). Premium unlocks the whole app. It
/// presents the value of the subscription, two auto-renewing plan cards
/// (Annual featured + pre-selected, Weekly), a single primary CTA that
/// purchases the selected plan, the required auto-renew disclosure, and the
/// Restore / Terms / Privacy footer.
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
    /// Optional escape hatch for the launch gate: shows a "Back" control that
    /// returns the user to onboarding without purchasing, so the "Go Premium"
    /// page is never a dead-end (App Store Guideline 5.6).
    var onExit: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager

    @State private var selectedOfferID: String?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showExample = false

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
                exampleSection

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
            if let onExit {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onExit()
                    } label: {
                        Label(t("Back", "Geri"), systemImage: "chevron.left")
                            .labelStyle(.titleAndIcon)
                    }
                    .tint(AppPalette.inkSoft)
                }
            }
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
                    .appFont(28, weight: .bold, design: .default)
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
                        .appFont(18, weight: .semibold, design: .default)
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
                .appFont(16, weight: .semibold, design: .default)
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

    // MARK: - 3b. "See an example" preview

    /// A reveal affordance + a STATIC, clearly-labeled sample of premium AI
    /// output (a swing report: 0–100 score + a few coaching bullets). Shows
    /// the value before the wall WITHOUT granting functional usage. The
    /// "Example" label keeps it honest — this is not real user data.
    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    showExample.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                        .font(.subheadline.weight(.bold))
                    Text(showExample
                         ? t("Hide example", "Örneği gizle")
                         : t("See an example", "Bir örnek gör"))
                        .font(.subheadline.weight(.bold))
                    Spacer(minLength: 0)
                    Image(systemName: showExample ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(AppPalette.clay)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(AppPalette.clay.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.clay.opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableCardStyle())

            if showExample {
                sampleReportCard
                    .transition(.opacity)
            }
        }
    }

    /// Static sample swing report, styled like the real `MatchAnalysisCard`
    /// (photo header band + parchment body). An "Example" pill makes clear
    /// this is illustrative, not the user's own analysis.
    private var sampleReportCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header band with score + Example pill (mirrors the real card).
            HStack(spacing: 12) {
                ScoreRing(size: 64, score: 82, accent: .white,
                          track: .white.opacity(0.28))
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Forehand · Sample", "Forehand · Örnek"))
                        .font(.caption.weight(.heavy))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.9))
                        .textCase(.uppercase)
                    Text(t("Swing score 82 / 100", "Vuruş skoru 82 / 100"))
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 8)
                Text(t("Example", "Örnek"))
                    .font(.caption2.weight(.heavy))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(AppPalette.clay)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandedPhoto("PhotoServe", scrim: .full, cornerRadius: 0)

            SwingReportText(text: sampleReportText)
                .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t("Example AI swing report", "Örnek AI vuruş raporu"))
    }

    private var sampleReportText: String {
        t(
            """
            **What's working**
            • Clean unit turn — your shoulders coil early, giving you time to load.
            • Solid contact point out in front, so the ball comes off with pace.

            **What to work on**
            • Your follow-through cuts short — finish over the shoulder for more topspin.
            • Add a small split-step before the swing to set up balance.

            **Try this next**
            • 10 shadow swings focusing on a full, relaxed finish.
            """,
            """
            **İyi olanlar**
            • Temiz gövde dönüşü — omuzların erken kuruluyor, yüklenmek için zaman tanıyor.
            • Vuruş noktası önde ve sağlam, bu yüzden top hızlı çıkıyor.

            **Geliştirilecekler**
            • Bitiriş kısa kalıyor — daha çok topspin için omuz üstünden bitir.
            • Vuruştan önce küçük bir split-step ekleyerek dengeni kur.

            **Sırada bunu dene**
            • Tam, rahat bir bitirişe odaklanarak 10 gölge vuruş.
            """
        )
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
            .appFont(22, weight: .regular, design: .default)
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
                "Hang tight — fetching current pricing from the App Store. If this persists, check your connection and tap Try again.",
                "Bir saniye — App Store’dan güncel fiyatlar alınıyor. Sürerse bağlantını kontrol edip Tekrar Dene’ye dokun."
            ))
            .font(.footnote)
            .foregroundStyle(AppPalette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            // Explicit retry so a cold/failed StoreKit load on the (non-
            // dismissible) gate never strands the reviewer on a spinner with
            // no way to recover — the prior "purchase flow did not display".
            Button {
                Task { await manager.loadOfferings() }
            } label: {
                Label(t("Try again", "Tekrar Dene"), systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
            .padding(.top, 4)
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
