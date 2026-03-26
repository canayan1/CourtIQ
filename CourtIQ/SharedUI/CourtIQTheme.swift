import SwiftUI

enum CourtIQTheme {
    static let accent = Color("AccentColor")
    static let background = Color(.systemBackground)
    static let cardBackground = Color(.secondarySystemBackground)
    static let cornerRadius: CGFloat = 16
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(CourtIQTheme.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: CourtIQTheme.cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
