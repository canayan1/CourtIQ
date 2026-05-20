import SwiftUI
import AuthenticationServices

struct PaywallView: View {
    let source: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager
    @State private var isWorking = false
    @State private var errorMessage: String?
    private let configuration = AppConfiguration.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                benefitsCard
                offerCards
                legalLinks
                legalNote
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("paywall.title"))
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
            Text(lang.t("paywall.subtitle"))
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text(lang.t("paywall.intro_body"))
                .foregroundStyle(AppPalette.inkSoft)

            if !session.isSignedInWithApple {
                VStack(alignment: .leading, spacing: 10) {
                    Text(lang.t("paywall.sign_in_required"))
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

    private var offerCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lang.t("paywall.choose_plan"))
                .font(.title3.bold())

            ForEach(session.subscriptionManager.offers) { offer in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(offer.title)
                                .font(.headline)
                            Text(offer.detail)
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.inkSoft)
                        }
                        Spacer()
                        if offer.isFeatured {
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
                            Text(session.subscriptionManager.isPremiumUnlocked ? lang.t("paywall.unlocked") : lang.t("paywall.continue"))
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking || session.subscriptionManager.isPremiumUnlocked || !session.isSignedInWithApple)
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

            if session.subscriptionManager.isPremiumUnlocked {
                Button(lang.t("paywall.manage")) {
                    session.openManageSubscriptions()
                }
                .buttonStyle(.bordered)
            }
        }
    }

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
        Text(lang.t("paywall.subscription_note"))
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
