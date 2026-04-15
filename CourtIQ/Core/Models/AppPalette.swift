import SwiftUI

enum AppPalette {
    static let clay = Color(red: 198 / 255, green: 92 / 255, blue: 49 / 255)
    static let clayBright = Color(red: 228 / 255, green: 137 / 255, blue: 79 / 255)
    static let cream = Color(red: 244 / 255, green: 236 / 255, blue: 221 / 255)
    static let parchment = Color(red: 252 / 255, green: 247 / 255, blue: 238 / 255)
    static let sand = Color(red: 225 / 255, green: 209 / 255, blue: 184 / 255)
    static let ink = Color(red: 30 / 255, green: 41 / 255, blue: 56 / 255)
    static let inkSoft = Color(red: 96 / 255, green: 91 / 255, blue: 84 / 255)
    static let moss = Color(red: 108 / 255, green: 131 / 255, blue: 102 / 255)
    static let alert = Color(red: 150 / 255, green: 73 / 255, blue: 42 / 255)

    static let heroGradient = LinearGradient(
        colors: [clay, clayBright, ink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let trainingGradient = LinearGradient(
        colors: [ink, clay, clayBright],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
