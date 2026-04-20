import SwiftUI

// MARK: - TennisPlayerLevel

enum TennisPlayerLevel: Int, CaseIterable {
    case ballKid          = 0
    case clubPlayer       = 1
    case competitor       = 2
    case tournamentPlayer = 3
    case pro              = 4

    // MARK: Derive from IQ rating

    static func level(for iqRating: Int) -> TennisPlayerLevel {
        switch iqRating {
        case ..<500:         return .ballKid
        case 500..<1000:     return .clubPlayer
        case 1000..<1500:    return .competitor
        case 1500..<2500:    return .tournamentPlayer
        default:             return .pro
        }
    }

    // MARK: Display

    var title: String {
        switch self {
        case .ballKid:          return "Ball Kid"
        case .clubPlayer:       return "Club Player"
        case .competitor:       return "Competitor"
        case .tournamentPlayer: return "Tournament Player"
        case .pro:              return "Pro"
        }
    }

    func localizedTitle(for language: AppLanguage) -> String {
        switch language {
        case .turkish:
            switch self {
            case .ballKid:          return "Çaylak"
            case .clubPlayer:       return "Kulüp Oyuncusu"
            case .competitor:       return "Rekabetçi"
            case .tournamentPlayer: return "Turnuva Oyuncusu"
            case .pro:              return "Pro"
            }
        default:
            return title
        }
    }

    var starCount: Int {
        switch self {
        case .ballKid:          return 0
        case .clubPlayer:       return 1
        case .competitor:       return 2
        case .tournamentPlayer: return 3
        case .pro:              return 5
        }
    }

    // MARK: Thresholds

    var lowerBound: Int {
        switch self {
        case .ballKid:          return 0
        case .clubPlayer:       return 500
        case .competitor:       return 1000
        case .tournamentPlayer: return 1500
        case .pro:              return 2500
        }
    }

    var upperBound: Int {
        switch self {
        case .ballKid:          return 500
        case .clubPlayer:       return 1000
        case .competitor:       return 1500
        case .tournamentPlayer: return 2500
        case .pro:              return 2500   // already max
        }
    }

    var nextLevel: TennisPlayerLevel? {
        TennisPlayerLevel(rawValue: rawValue + 1)
    }

    func progress(for iqRating: Int) -> Double {
        guard self != .pro else { return 1.0 }
        let span = upperBound - lowerBound
        let done = max(0, iqRating - lowerBound)
        return min(1.0, Double(done) / Double(span))
    }

    // MARK: Colors

    /// Primary accent — used for text, ring, figure.
    var accent: Color {
        switch self {
        case .ballKid:          return Color(white: 0.55)
        case .clubPlayer:       return Color(red: 0.72, green: 0.38, blue: 0.20)   // clay
        case .competitor:       return Color(red: 0.22, green: 0.48, blue: 0.76)   // hard-court blue
        case .tournamentPlayer: return Color(red: 0.18, green: 0.58, blue: 0.32)   // grass green
        case .pro:              return Color(red: 0.74, green: 0.55, blue: 0.10)   // gold
        }
    }

    /// Lighter tint — used for badge background and ring glow.
    var accentSoft: Color {
        switch self {
        case .ballKid:          return Color(white: 0.88)
        case .clubPlayer:       return Color(red: 0.96, green: 0.78, blue: 0.58)
        case .competitor:       return Color(red: 0.68, green: 0.85, blue: 0.98)
        case .tournamentPlayer: return Color(red: 0.66, green: 0.94, blue: 0.70)
        case .pro:              return Color(red: 1.00, green: 0.90, blue: 0.48)
        }
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [accentSoft.opacity(0.50), accent.opacity(0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: Badge figure

    var symbolName: String {
        // Ball Kid only sees a tennis ball; everyone else sees the player figure.
        self == .ballKid ? "tennisball.fill" : "figure.tennis"
    }

    var figureSize: CGFloat {
        switch self {
        case .ballKid:          return 38
        case .clubPlayer:       return 42
        case .competitor:       return 46
        case .tournamentPlayer: return 50
        case .pro:              return 54
        }
    }
}
