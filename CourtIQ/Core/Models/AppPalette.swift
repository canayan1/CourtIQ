import SwiftUI

enum AppPalette {
    static let clay = Color(red: 198 / 255, green: 92 / 255, blue: 49 / 255)
    static let clayBright = Color(red: 228 / 255, green: 137 / 255, blue: 79 / 255)
    // Deepened from (244,236,221) → a warmer oat so the lighter parchment cards
    // and the photo cards separate from the page background with real contrast.
    static let cream = Color(red: 233 / 255, green: 222 / 255, blue: 203 / 255)
    static let parchment = Color(red: 252 / 255, green: 247 / 255, blue: 238 / 255)
    static let sand = Color(red: 225 / 255, green: 209 / 255, blue: 184 / 255)
    static let ink = Color(red: 30 / 255, green: 41 / 255, blue: 56 / 255)
    // Darkened from (96,91,84) → (74,70,64): same warm hue, lower luminance so
    // secondary/caption/eyebrow text clears WCAG 4.5:1 on parchment/cream.
    static let inkSoft = Color(red: 74 / 255, green: 70 / 255, blue: 64 / 255)
    static let moss = Color(red: 108 / 255, green: 131 / 255, blue: 102 / 255)
    static let alert = Color(red: 150 / 255, green: 73 / 255, blue: 42 / 255)
    static let mossDeep = Color(red: 78 / 255, green: 106 / 255, blue: 74 / 255)
    static let gold = Color(red: 217 / 255, green: 158 / 255, blue: 25 / 255)

    // Soft per-feature tints + matching deep same-family text colors. Used by
    // the three "tinted card" surfaces (Recent activity, Matches rows, Recover
    // rows) that drop their photo/parchment background for a solid brand color.
    // Each text/tint pair clears WCAG ~4.5:1.
    static let clayTint = Color(red: 242 / 255, green: 223 / 255, blue: 212 / 255)
    static let clayText = Color(red: 150 / 255, green: 70 / 255, blue: 38 / 255)
    static let mossTint = Color(red: 221 / 255, green: 231 / 255, blue: 218 / 255)
    static let mossText = Color(red: 60 / 255, green: 92 / 255, blue: 60 / 255)
    static let goldTint = Color(red: 236 / 255, green: 226 / 255, blue: 200 / 255)
    static let goldText = Color(red: 130 / 255, green: 100 / 255, blue: 28 / 255)

    // Court surface colors — used by tennis components
    enum CourtSurface {
        case clay, grass, hard, cream, night

        var base: Color {
            switch self {
            case .clay:  return Color(red: 197/255, green: 106/255, blue:  62/255)
            case .grass: return Color(red:  62/255, green: 119/255, blue:  69/255)
            case .hard:  return Color(red:  54/255, green: 114/255, blue: 168/255)
            case .cream: return Color(red: 225/255, green: 209/255, blue: 184/255)
            case .night: return Color(red:  28/255, green:  42/255, blue:  58/255)
            }
        }
        var dark: Color {
            switch self {
            case .clay:  return Color(red: 143/255, green:  70/255, blue:  35/255)
            case .grass: return Color(red:  39/255, green:  83/255, blue:  46/255)
            case .hard:  return Color(red:  35/255, green:  84/255, blue: 130/255)
            case .cream: return Color(red: 181/255, green: 162/255, blue: 133/255)
            case .night: return Color(red:  13/255, green:  23/255, blue:  34/255)
            }
        }
        var sky: Color {
            switch self {
            case .clay:  return Color(red: 244/255, green: 236/255, blue: 221/255)
            case .grass: return Color(red: 232/255, green: 240/255, blue: 218/255)
            case .hard:  return Color(red: 220/255, green: 234/255, blue: 244/255)
            case .cream: return Color(red: 252/255, green: 247/255, blue: 238/255)
            case .night: return Color(red:  58/255, green:  36/255, blue:  24/255)
            }
        }
        var line: Color {
            self == .night
                ? Color(red: 232/255, green: 221/255, blue: 200/255)
                : Color(red: 252/255, green: 247/255, blue: 238/255)
        }
    }

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

    /// Gold→clay accent for the flagship AI Swing Analysis hero on the Train hub.
    static let swingHeroGradient = LinearGradient(
        colors: [gold, clayBright, clay],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
