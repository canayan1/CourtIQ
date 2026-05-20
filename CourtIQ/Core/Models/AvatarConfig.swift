import SwiftUI

/// User's tennis-player avatar configuration. Every customization choice
/// is a small enum — the actual visual is rendered procedurally from
/// SwiftUI Shape primitives in `TennisAvatarView`, so we never need to
/// ship art assets.
struct AvatarConfig: Codable, Hashable {
    var outfitID: String
    var racketID: String
    var courtSurfaceID: String
    var accentID: String
    var stanceID: String

    static let `default` = AvatarConfig(
        outfitID: AvatarOutfit.clayWhite.rawValue,
        racketID: AvatarRacket.classicBlack.rawValue,
        courtSurfaceID: AvatarCourtBg.clayCourt.rawValue,
        accentID: AvatarAccent.none.rawValue,
        stanceID: AvatarStance.ready.rawValue
    )

    var outfit: AvatarOutfit {
        AvatarOutfit(rawValue: outfitID) ?? .clayWhite
    }
    var racket: AvatarRacket {
        AvatarRacket(rawValue: racketID) ?? .classicBlack
    }
    var courtSurface: AvatarCourtBg {
        AvatarCourtBg(rawValue: courtSurfaceID) ?? .clayCourt
    }
    var accent: AvatarAccent {
        AvatarAccent(rawValue: accentID) ?? .none
    }
    var stance: AvatarStance {
        AvatarStance(rawValue: stanceID) ?? .ready
    }
}

// MARK: - Customization catalogs
//
// Each catalog item carries its display name, color palette, and a unique
// rawValue used both for persistence and unlock matching.

enum AvatarOutfit: String, CaseIterable, Identifiable {
    case clayWhite
    case classicNavy
    case sunsetOrange
    case courtRoyal
    case neonLime
    case shadowBlack
    case grandSlamCream
    case midnightTeal

    var id: String { rawValue }

    var jerseyColor: Color {
        switch self {
        case .clayWhite:      return .white
        case .classicNavy:    return Color(red: 0.13, green: 0.20, blue: 0.40)
        case .sunsetOrange:   return AppPalette.clay
        case .courtRoyal:     return Color(red: 0.20, green: 0.40, blue: 0.75)
        case .neonLime:       return Color(red: 0.70, green: 0.92, blue: 0.10)
        case .shadowBlack:    return Color(red: 0.10, green: 0.10, blue: 0.12)
        case .grandSlamCream: return AppPalette.cream
        case .midnightTeal:   return Color(red: 0.08, green: 0.32, blue: 0.38)
        }
    }
    var shortColor: Color {
        switch self {
        case .clayWhite:      return Color(red: 0.92, green: 0.92, blue: 0.92)
        case .classicNavy:    return Color(red: 0.10, green: 0.15, blue: 0.30)
        case .sunsetOrange:   return Color(red: 0.55, green: 0.30, blue: 0.16)
        case .courtRoyal:     return Color(red: 0.14, green: 0.30, blue: 0.60)
        case .neonLime:       return Color(red: 0.10, green: 0.10, blue: 0.12)
        case .shadowBlack:    return Color(red: 0.20, green: 0.20, blue: 0.22)
        case .grandSlamCream: return Color(red: 0.85, green: 0.78, blue: 0.62)
        case .midnightTeal:   return Color(red: 0.05, green: 0.20, blue: 0.24)
        }
    }
    var displayName: String {
        switch self {
        case .clayWhite:      return "Clay White"
        case .classicNavy:    return "Classic Navy"
        case .sunsetOrange:   return "Sunset"
        case .courtRoyal:     return "Royal"
        case .neonLime:       return "Neon Lime"
        case .shadowBlack:    return "Shadow"
        case .grandSlamCream: return "Grand Slam"
        case .midnightTeal:   return "Midnight"
        }
    }
}

enum AvatarRacket: String, CaseIterable, Identifiable {
    case classicBlack
    case clayOrange
    case neonYellow
    case wimbledonGreen
    case carbonGray
    case championGold

    var id: String { rawValue }

    var headColor: Color {
        switch self {
        case .classicBlack:   return Color(red: 0.10, green: 0.10, blue: 0.12)
        case .clayOrange:     return AppPalette.clay
        case .neonYellow:     return Color(red: 0.95, green: 0.92, blue: 0.10)
        case .wimbledonGreen: return Color(red: 0.20, green: 0.45, blue: 0.25)
        case .carbonGray:     return Color(red: 0.30, green: 0.30, blue: 0.32)
        case .championGold:   return AppPalette.gold
        }
    }
    var accentColor: Color {
        switch self {
        case .classicBlack:   return .white
        case .clayOrange:     return .white
        case .neonYellow:     return Color(red: 0.10, green: 0.10, blue: 0.12)
        case .wimbledonGreen: return Color(red: 0.95, green: 0.92, blue: 0.10)
        case .carbonGray:     return AppPalette.clay
        case .championGold:   return Color(red: 0.10, green: 0.10, blue: 0.12)
        }
    }
    var displayName: String {
        switch self {
        case .classicBlack:   return "Classic"
        case .clayOrange:     return "Clay"
        case .neonYellow:     return "Neon"
        case .wimbledonGreen: return "Wimbledon"
        case .carbonGray:     return "Carbon"
        case .championGold:   return "Champion"
        }
    }
}

enum AvatarCourtBg: String, CaseIterable, Identifiable {
    case clayCourt
    case grassCourt
    case hardCourt
    case nightCourt
    case sunsetCourt

    var id: String { rawValue }

    var surface: AppPalette.CourtSurface {
        switch self {
        case .clayCourt:    return .clay
        case .grassCourt:   return .grass
        case .hardCourt:    return .hard
        case .nightCourt:   return .night
        case .sunsetCourt:  return .clay   // gradient variation handled in view
        }
    }
    var displayName: String {
        switch self {
        case .clayCourt:    return "Clay"
        case .grassCourt:   return "Grass"
        case .hardCourt:    return "Hard"
        case .nightCourt:   return "Night"
        case .sunsetCourt:  return "Sunset"
        }
    }
}

enum AvatarAccent: String, CaseIterable, Identifiable {
    case none
    case headband
    case wristbands
    case capForward

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:        return "None"
        case .headband:    return "Headband"
        case .wristbands:  return "Wristbands"
        case .capForward:  return "Cap"
        }
    }
}

enum AvatarStance: String, CaseIterable, Identifiable {
    case ready
    case proPose

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ready:    return "Ready"
        case .proPose:  return "Pro pose"
        }
    }
}
