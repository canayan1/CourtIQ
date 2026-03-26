import SwiftUI

struct PaywallView: View {
    @Environment(DIContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.yellow)

                    Text(String(localized: "CourtIQ Premium"))
                        .font(.largeTitle.bold())

                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "infinity", text: String(localized: "Unlimited quizzes per day"))
                        FeatureRow(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", text: String(localized: "Full tip archive access"))
                        FeatureRow(icon: "chart.bar.fill", text: String(localized: "Complete progress history"))
                        FeatureRow(icon: "lightbulb.fill", text: String(localized: "Detailed quiz explanations"))
                        FeatureRow(icon: "icloud.fill", text: String(localized: "Full offline mode"))
                    }
                    .cardStyle()

                    VStack(spacing: 12) {
                        Button(String(localized: "Monthly — $4.99 / month")) {
                            Task { await purchase(productID: PremiumGate.monthlyProductID) }
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button(String(localized: "Annual — $29.99 / year")) {
                            Task { await purchase(productID: PremiumGate.annualProductID) }
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button(String(localized: "Restore Purchases")) {
                            Task { await restore() }
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let error = errorMessage {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
            }
            .overlay { if isLoading { LoadingView() } }
        }
    }

    private func purchase(productID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await container.premiumGate.purchase(productID: productID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await container.premiumGate.restorePurchases()
            if container.premiumGate.isPremium { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(CourtIQTheme.accent)
                .frame(width: 24)
            Text(text)
                .font(.callout)
        }
    }
}
