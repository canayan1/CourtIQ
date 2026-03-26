import SwiftUI

struct PremiumBadge: View {
    var body: some View {
        Label(String(localized: "Premium"), systemImage: "crown.fill")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow)
            .clipShape(Capsule())
    }
}
