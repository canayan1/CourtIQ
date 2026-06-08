import Foundation

/// Output of the deterministic scorer. Language-neutral (keys + ratings +
/// recommendation slots) so the UI localizes by key and stays identical on
/// both devices.

enum CompatBand: String, Codable {
    case strong       // overall >= 80
    case workable     // 60...79
    case needsPlan    // < 60
}

enum DimensionRating: String, Codable { case green, yellow, red }

enum PlayerSlot: String, Codable { case a = "A"; case b = "B" }

/// The two compatibility axes.
enum DoublesAxis: String, Codable { case tactical, chemistry }

/// Stable dimension identifiers; each belongs to one axis.
enum DoublesDimension: String, Codable, CaseIterable {
    // tactical
    case courtSide, netBaseline, handedness, formation, serve
    // chemistry
    case comms, temperament, goal

    var axis: DoublesAxis {
        switch self {
        case .courtSide, .netBaseline, .handedness, .formation, .serve: return .tactical
        case .comms, .temperament, .goal: return .chemistry
        }
    }
}

enum StartingFormation: String, Codable {
    case bothUp, oneUpOneBackPoach, startBackApproach
}

struct DimensionScore: Codable, Equatable {
    let dimension: DoublesDimension
    let rating: DimensionRating
    let sub: Double            // 0...1 contribution before weighting
}

struct DoublesResult: Codable, Equatable {
    let score: Int                       // overall 0...100 (avg of the two axes)
    let tacticalScore: Int               // 0...100
    let chemistryScore: Int              // 0...100
    let band: CompatBand
    let dimensions: [DimensionScore]     // all dimensions, tactical then chemistry

    // Derived team setup.
    let serveFirst: PlayerSlot
    let deuceReturner: PlayerSlot
    let adReturner: PlayerSlot
    let startingFormation: StartingFormation

    let strengthKeys: [DoublesDimension]
    let watchOutKeys: [DoublesDimension]

    func dimension(_ d: DoublesDimension) -> DimensionScore? {
        dimensions.first { $0.dimension == d }
    }
}
