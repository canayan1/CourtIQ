import SwiftUI

struct PremiumUpsellBanner: View {
    let message: String
    @State private var showPaywall: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "CourtIQ Premium"), systemImage: "crown.fill")
                .font(.headline)
                .foregroundStyle(.yellow)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(String(localized: "Upgrade Now")) {
                showPaywall = true
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}
