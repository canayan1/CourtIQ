import SwiftUI
import AuthenticationServices

struct PaywallView: View {
    let source: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: UserSessionManager
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                benefitsCard
                offerCards
                legalNote
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle("All Access")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .alert("Purchase issue", isPresented: Binding(get: {
            errorMessage != nil
        }, set: { newValue in
            if !newValue {
                errorMessage = nil
            }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Unlock the full CourtIQ stack")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("You came from \(source). Premium unlocks the full training library, mobility flows, archived quiz insights, and community participation.")
                .foregroundStyle(AppPalette.inkSoft)

            if !session.isSignedInWithApple {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sign in with Apple is required before purchase.")
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
            Text("What unlocks")
                .font(.title3.bold())

            ForEach(session.subscriptionManager.premiumBenefits, id: \.self) { benefit in
                Label(benefit, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppPalette.ink)
            }

            if session.subscriptionManager.integrationMode == .preview {
                Text("App Store testing mode is active until StoreKit or RevenueCat keys are configured.")
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
            Text("Choose your plan")
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
                            Text("Best value")
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
                            Text(session.subscriptionManager.isPremiumUnlocked ? "Unlocked" : "Continue")
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

            Button("Restore Purchases") {
                Task {
                    isWorking = true
                    defer { isWorking = false }
                    await session.restorePurchases()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isWorking)

            if session.subscriptionManager.isPremiumUnlocked {
                Button("Manage Subscription") {
                    session.openManageSubscriptions()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var legalNote: some View {
        Text("Subscriptions renew automatically unless canceled in App Store settings at least 24 hours before the end of the current period.")
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
