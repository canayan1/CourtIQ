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
