import Foundation

/// A saved doubles partner mini-profile. The level + style raw values reuse the
/// Tennis Profile enums (`TennisLevel` raw Int as String, `TennisArchetype`
/// rawValue), and handedness reuses `SwingHandedness`. All optional fields are
/// nil when the user left them on "no preference" / blank — the summary builder
/// simply omits them.
struct DoublesPartner: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    /// `TennisLevel.rawValue` as a String (the enum is `Int`-backed), or nil.
    var levelRaw: String?
    /// `SwingHandedness.rawValue` ("right" | "left"), or nil.
    var handednessRaw: String?
    /// `TennisArchetype.rawValue` ("aggressiveBaseliner" …), or nil.
    var styleRaw: String?
    var strengths: String
    var weaknesses: String

    init(
        id: UUID = UUID(),
        name: String,
        levelRaw: String? = nil,
        handednessRaw: String? = nil,
        styleRaw: String? = nil,
        strengths: String = "",
        weaknesses: String = ""
    ) {
        self.id = id
        self.name = name
        self.levelRaw = levelRaw
        self.handednessRaw = handednessRaw
        self.styleRaw = styleRaw
        self.strengths = strengths
        self.weaknesses = weaknesses
    }

    // MARK: - Typed accessors (reuse the existing enums)

    /// Reconstructs the typed `TennisLevel` from the stored rawValue. The level
    /// enum is `Int`-backed, so we round-trip through `Int`.
    var level: TennisLevel? {
        guard let levelRaw, let intValue = Int(levelRaw) else { return nil }
        return TennisLevel(rawValue: intValue)
    }

    var handedness: SwingHandedness? {
        guard let handednessRaw else { return nil }
        return SwingHandedness(rawValue: handednessRaw)
    }

    var style: TennisArchetype? {
        guard let styleRaw else { return nil }
        return TennisArchetype(rawValue: styleRaw)
    }
}

/// A saved doubles compatibility report for one partner: the AI coaching text
/// plus an optional 0–100 compatibility score. Mirrors `SwingAnalysisRecord`'s
/// shape (Codable, Identifiable) but is text-only — no media on disk.
struct DoublesReport: Codable, Identifiable, Equatable {
    let id: UUID
    let partnerId: UUID
    let date: Date
    let score: Int?
    let reportText: String

    init(
        id: UUID = UUID(),
        partnerId: UUID,
        date: Date = Date(),
        score: Int?,
        reportText: String
    ) {
        self.id = id
        self.partnerId = partnerId
        self.date = date
        self.score = score
        self.reportText = reportText
    }
}

// MARK: - Deterministic compatibility score

/// Rule-based doubles compatibility score (0–100). The AI writes the
/// *explanation*; the number is computed here so it is consistent and never
/// hallucinated. The heuristics are tennis-sound: level proximity (closer
/// levels pair more cohesively), play-style complementarity (an attacker + a
/// steadier, or net + baseline, beat two of a kind), and a small bonus for a
/// left-handed partner (covers the ad court + gives different serve angles).
enum DoublesCompatibility {
    /// - Returns: the 0–100 score plus short English factor phrases for the
    ///   coaching prompt to explain.
    static func evaluate(
        userLevel: TennisLevel?,
        userArchetype: TennisArchetype?,
        partner: DoublesPartner
    ) -> (score: Int, factors: [String]) {
        var score = 68
        var factors: [String] = []

        if let ul = userLevel, let pl = partner.level {
            switch abs(ul.rawValue - pl.rawValue) {
            case 0:  score += 10; factors.append("same level")
            case 1:  score += 6;  factors.append("close levels")
            case 2:  score += 0;  factors.append("a level gap to bridge")
            case 3:  score -= 8;  factors.append("a wide level gap")
            default: score -= 14; factors.append("a very wide level gap")
            }
        }

        if let ua = userArchetype, let pa = partner.style {
            let delta = archetypeFit(ua, pa)
            score += delta
            if delta >= 10 { factors.append("complementary play styles") }
            else if delta >= 7 { factors.append("a flexible all-court fit") }
            else if delta < 0 { factors.append("two similar play styles") }
        }

        if partner.handedness == .left {
            score += 3
            factors.append("a left-handed partner (covers the ad court)")
        }

        return (min(96, max(40, score)), factors)
    }

    /// Complementarity delta. Among the three committed styles (aggressive
    /// baseliner, counterpuncher, serve-volleyer) any two *distinct* styles
    /// complement; the same style twice is redundant; an all-court player glues
    /// to anyone; a developing player is neutral (still building the basics).
    private static func archetypeFit(_ a: TennisArchetype, _ b: TennisArchetype) -> Int {
        if a == .developing || b == .developing { return 0 }
        if a == .allCourt || b == .allCourt { return 7 }
        if a == b { return -3 }
        return 10
    }
}
