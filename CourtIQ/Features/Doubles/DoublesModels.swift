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
    /// Legacy 0–100 score. Kept optional so old saved reports still decode; new
    /// reports leave it nil and carry `tierRaw` instead (we no longer surface a
    /// number — see DoublesFit).
    let score: Int?
    /// The honest fit tier (`DoublesCompatTier.rawValue`). Optional so pre-tier
    /// reports decode; when present it drives the UI instead of `score`.
    let tierRaw: String?
    let reportText: String

    init(
        id: UUID = UUID(),
        partnerId: UUID,
        date: Date = Date(),
        score: Int? = nil,
        tierRaw: String? = nil,
        reportText: String
    ) {
        self.id = id
        self.partnerId = partnerId
        self.date = date
        self.score = score
        self.tierRaw = tierRaw
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
/// A qualitative doubles fit read. We deliberately DON'T surface a 0–100 number:
/// the underlying heuristic only ever spans ~51–91 and collapses to a constant
/// when the user has no Tennis Profile, so a precise-looking score is misleading
/// (measured: docs/PRODUCT-COHERENCE.md). Instead we show an honest tier + the
/// specific strengths and watch-outs behind it — measure, don't over-claim.
struct DoublesFit {
    let tier: DoublesCompatTier
    let strengths: [String]      // English factor phrases (the positives)
    let cautions: [String]       // English factor phrases (the watch-outs)
    /// The user has a completed Tennis Profile, so the read uses BOTH players.
    /// Without it we only know the partner — the UI says so instead of faking a
    /// confident fit.
    let hasUserProfile: Bool
}

enum DoublesCompatibility {
    /// Honest, signal-derived fit. The tier reflects the ACTUAL pairing signal
    /// (level proximity + style complementarity), not an inflated base number,
    /// and separates strengths from watch-outs for the card + the AI to explain.
    static func evaluate(
        userLevel: TennisLevel?,
        userArchetype: TennisArchetype?,
        partner: DoublesPartner
    ) -> DoublesFit {
        var strengths: [String] = []
        var cautions: [String] = []
        let hasUserProfile = userLevel != nil && userArchetype != nil

        // Level proximity signal.
        var levelGap: Int? = nil
        if let ul = userLevel, let pl = partner.level {
            let gap = abs(ul.rawValue - pl.rawValue)
            levelGap = gap
            switch gap {
            case 0:  strengths.append("you're at the same level")
            case 1:  strengths.append("close levels")
            case 2:  cautions.append("a level gap to bridge")
            default: cautions.append("a wide level gap — lean on the stronger side")
            }
        }

        // Play-style complementarity signal.
        var styleFit: Int? = nil
        if let ua = userArchetype, let pa = partner.style {
            let delta = archetypeFit(ua, pa)
            styleFit = delta
            if delta >= 10 { strengths.append("complementary play styles") }
            else if delta >= 7 { strengths.append("an all-court partner who adapts to you") }
            else if delta < 0 { cautions.append("two similar styles — split your roles clearly") }
        }

        if partner.handedness == .left {
            strengths.append("a left-handed partner (covers the ad court)")
        }

        // Tier from the real signal, not a compressed number:
        //  • great — close level AND a genuinely complementary/all-court style
        //  • work  — a wide level gap, or redundant styles across a gap
        //  • solid — everything in between (and the default when signal is thin)
        let tier: DoublesCompatTier
        if let g = levelGap, g <= 1, let s = styleFit, s >= 7 {
            tier = .great
        } else if (levelGap ?? 0) >= 3 || ((styleFit ?? 0) < 0 && (levelGap ?? 0) >= 2) {
            tier = .work
        } else {
            tier = .solid
        }

        return DoublesFit(tier: tier, strengths: strengths, cautions: cautions,
                          hasUserProfile: hasUserProfile)
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
