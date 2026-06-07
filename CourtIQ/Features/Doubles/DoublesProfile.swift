import Foundation

/// One player's answers to the doubles compatibility questionnaire.
///
/// Pure value type with no app/UI dependencies so the scoring engine can
/// be unit-validated standalone and produce identical results on both
/// devices (the same `DoublesProfile` pair → the same `DoublesResult`).
/// Exchanged peer-to-peer over MultipeerConnectivity (on-court) or via a
/// short-lived invite session (remote).

enum DoublesSide: String, Codable, CaseIterable {
    case deuce, ad, either
}

enum NetComfort: String, Codable, CaseIterable {
    case net          // loves the net
    case mixed        // all-court
    case baseline     // prefers the baseline
}

enum PoachTendency: String, Codable, CaseIterable {
    case aggressive, selective, holds
}

enum CommStyle: String, Codable, CaseIterable {
    case vocal, moderate, quiet
}

enum PressureStyle: String, Codable, CaseIterable {
    case goForIt, percentage, defend
}

enum FormationComfort: String, Codable, CaseIterable {
    case flexible      // comfortable with I-formation / Australian
    case standardOnly
}

enum Handedness: String, Codable, CaseIterable {
    case right, left
}

struct DoublesProfile: Codable, Equatable, Hashable {
    var preferredSide: DoublesSide
    var netComfort: NetComfort
    var poach: PoachTendency
    var comms: CommStyle
    var pressure: PressureStyle
    var formation: FormationComfort
    var handedness: Handedness
    /// 1...5 self-rating; drives serve order.
    var serveStrength: Int
    /// 1...5 self-rating; drives return-side assignment on a clash.
    var returnStrength: Int

    /// A neutral default (used to seed the questionnaire UI).
    static var unset: DoublesProfile {
        DoublesProfile(
            preferredSide: .either,
            netComfort: .mixed,
            poach: .selective,
            comms: .moderate,
            pressure: .percentage,
            formation: .standardOnly,
            handedness: .right,
            serveStrength: 3,
            returnStrength: 3
        )
    }
}
