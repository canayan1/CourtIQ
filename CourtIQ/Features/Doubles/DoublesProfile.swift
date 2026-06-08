import Foundation

/// One player's answers to the doubles compatibility questionnaire.
/// Two axes: TACTICAL (do your games complement on court) and CHEMISTRY
/// (will you work as partners). Pure value type — no app/UI deps — so the
/// scorer is unit-validatable and identical on both devices.

// MARK: Tactical
enum DoublesSide: String, Codable, CaseIterable { case deuce, ad, either }
enum NetComfort: String, Codable, CaseIterable {
    case net          // loves the net
    case mixed        // all-court
    case baseline     // prefers the baseline
}
enum FormationComfort: String, Codable, CaseIterable {
    case flexible      // comfortable with I-formation / Australian
    case standardOnly
}
enum Handedness: String, Codable, CaseIterable { case right, left }

// MARK: Chemistry
enum CommStyle: String, Codable, CaseIterable { case vocal, moderate, quiet }
/// On-court emotional temperament (not tactical risk).
enum Temperament: String, Codable, CaseIterable {
    case calm          // steadying anchor
    case balanced
    case fiery         // fires up / emotional
}
/// What the player wants out of doubles.
enum DoublesGoal: String, Codable, CaseIterable {
    case win           // here to compete / win
    case improve       // here to get better
    case fun           // here for fun / social
}

struct DoublesProfile: Codable, Equatable, Hashable {
    // Tactical
    var preferredSide: DoublesSide
    var netComfort: NetComfort
    var handedness: Handedness
    var formation: FormationComfort
    var serveStrength: Int     // 1...5 — serve dimension + serve order
    var returnStrength: Int    // 1...5 — return-side recommendation
    // Chemistry
    var comms: CommStyle
    var temperament: Temperament
    var goal: DoublesGoal

    static var unset: DoublesProfile {
        DoublesProfile(preferredSide: .either, netComfort: .mixed, handedness: .right,
                       formation: .standardOnly, serveStrength: 3, returnStrength: 3,
                       comms: .moderate, temperament: .balanced, goal: .improve)
    }
}
