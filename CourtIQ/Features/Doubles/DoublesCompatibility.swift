import Foundation

/// Deterministic doubles compatibility scorer. Pure function of two
/// `DoublesProfile`s → a `DoublesResult`. No app/UI deps, no randomness,
/// no dates → identical output on both devices for the same inputs.
///
/// Each dimension yields a 0...1 sub-score and a rating; the weighted sum
/// (weights below) is scaled to 0...100. Rules encode standard doubles
/// strategy (see docs/FEATURE_SPEC_doubles_v1.1.md §3).
enum DoublesCompatibility {

    // Dimension weights (sum = 100).
    private static let weights: [DoublesDimension: Double] = [
        .courtSide:   25,
        .netBaseline: 20,
        .comms:       15,
        .pressure:    15,
        .formation:   10,
        .handedness:  10,
        .serve:        5,
    ]

    static func score(_ a: DoublesProfile, _ b: DoublesProfile) -> DoublesResult {
        let dims: [DimensionScore] = [
            courtSide(a, b),
            netBaseline(a, b),
            comms(a, b),
            pressure(a, b),
            formation(a, b),
            handedness(a, b),
            serve(a, b),
        ]

        // Weighted score → 0...100.
        var weighted = 0.0
        var total = 0.0
        for d in dims {
            let w = weights[d.dimension] ?? 0
            weighted += d.sub * w
            total += w
        }
        let score = total > 0 ? Int((weighted / total * 100).rounded()) : 0
        let band: CompatBand = score >= 80 ? .strong : (score >= 60 ? .workable : .needsPlan)

        // Strengths = greens (highest-weight first). Watch-outs = reds
        // first, then yellows (highest-weight first). Cap for a tidy UI.
        let byWeightDesc: (DimensionScore, DimensionScore) -> Bool = {
            (weights[$0.dimension] ?? 0) > (weights[$1.dimension] ?? 0)
        }
        let strengths = dims.filter { $0.rating == .green }
            .sorted(by: byWeightDesc).map { $0.dimension }
        let reds = dims.filter { $0.rating == .red }.sorted(by: byWeightDesc)
        let yellows = dims.filter { $0.rating == .yellow }.sorted(by: byWeightDesc)
        let watchOuts = (reds + yellows).map { $0.dimension }

        let (deuce, ad) = returnSides(a, b)

        return DoublesResult(
            score: score,
            band: band,
            dimensions: dims,
            serveFirst: a.serveStrength >= b.serveStrength ? .a : .b,
            deuceReturner: deuce,
            adReturner: ad,
            startingFormation: startingFormation(a, b),
            strengthKeys: Array(strengths.prefix(3)),
            watchOutKeys: Array(watchOuts.prefix(2))
        )
    }

    // MARK: - Dimensions

    /// Court-side fit — the biggest practical factor. Two players who both
    /// want the same fixed side clash (one must play their weak side).
    private static func courtSide(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        let sa = a.preferredSide, sb = b.preferredSide
        let sub: Double; let rating: DimensionRating
        if sa == .either && sb == .either {
            sub = 0.8; rating = .yellow                 // fine, just decide
        } else if sa == .either || sb == .either {
            sub = 1.0; rating = .green                  // one flexes
        } else if sa != sb {
            sub = 1.0; rating = .green                  // complementary (deuce+ad)
        } else {
            sub = 0.2; rating = .red                    // both want the same side
        }
        return DimensionScore(dimension: .courtSide, rating: rating, sub: sub)
    }

    /// Net/baseline balance — ideally someone owns the net. Two
    /// baseline-only players are a real doubles liability.
    private static func netBaseline(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        let pair = Set([a.netComfort, b.netComfort])
        let sub: Double; let rating: DimensionRating
        if pair == [.baseline] {
            sub = 0.3; rating = .red                    // both baseline-only
        } else if pair == [.net] {
            sub = 0.6; rating = .yellow                 // both want net; lob-vulnerable
        } else if pair == [.mixed] {
            sub = 0.85; rating = .green                 // both flexible
        } else if pair.contains(.net) {
            sub = 1.0; rating = .green                  // net + (mixed|baseline): balanced
        } else {
            sub = 0.7; rating = .yellow                 // mixed + baseline
        }
        return DimensionScore(dimension: .netBaseline, rating: rating, sub: sub)
    }

    /// Communication alignment — two quiet players risk middle-ball chaos.
    private static func comms(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        let pair = Set([a.comms, b.comms])
        let sub: Double; let rating: DimensionRating
        if pair == [.quiet] {
            sub = 0.3; rating = .red
        } else if pair.contains(.quiet) {
            sub = 0.6; rating = .yellow                 // one carries the calls
        } else if pair == [.vocal] {
            sub = 1.0; rating = .green
        } else {
            sub = 0.85; rating = .green                 // vocal+moderate or both moderate
        }
        return DimensionScore(dimension: .comms, rating: rating, sub: sub)
    }

    /// Risk/pressure alignment — matched appetite is cohesive; opposite
    /// can complement but needs an agreed who-goes-for-it.
    private static func pressure(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        func rank(_ p: PressureStyle) -> Int {
            switch p { case .goForIt: return 2; case .percentage: return 1; case .defend: return 0 }
        }
        let gap = abs(rank(a.pressure) - rank(b.pressure))
        let sub: Double; let rating: DimensionRating
        switch gap {
        case 0: sub = 1.0; rating = .green
        case 1: sub = 0.75; rating = .yellow
        default: sub = 0.5; rating = .yellow            // opposite ends
        }
        return DimensionScore(dimension: .pressure, rating: rating, sub: sub)
    }

    /// Formation range — both comfortable with I-formation/Australian =
    /// tactical flexibility against strong returners.
    private static func formation(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        let flex = [a.formation, b.formation].filter { $0 == .flexible }.count
        let sub: Double; let rating: DimensionRating
        switch flex {
        case 2: sub = 1.0; rating = .green
        case 1: sub = 0.7; rating = .yellow
        default: sub = 0.5; rating = .yellow
        }
        return DimensionScore(dimension: .formation, rating: rating, sub: sub)
    }

    /// Handedness synergy — a lefty+righty pair can put both forehands in
    /// the middle (or cover both alleys with forehands). Same-handed is
    /// fine, just no bonus, with a small middle-ball note.
    private static func handedness(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        if a.handedness != b.handedness {
            return DimensionScore(dimension: .handedness, rating: .green, sub: 1.0)
        }
        return DimensionScore(dimension: .handedness, rating: .yellow, sub: 0.7)
    }

    /// Serve cohesion — minor; mostly feeds serve order. Small bonus when
    /// both have a dependable serve.
    private static func serve(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        let avg = Double(a.serveStrength + b.serveStrength) / 2.0
        let sub = max(0.0, min(1.0, (avg - 1.0) / 4.0))   // 1→0, 5→1
        let rating: DimensionRating = avg >= 3.5 ? .green : (avg >= 2.5 ? .yellow : .red)
        return DimensionScore(dimension: .serve, rating: rating, sub: sub)
    }

    // MARK: - Derived recommendations

    /// Assign return sides. Honor preferences; on a same-side clash, the
    /// higher-returnStrength (more clutch) player takes the ad court,
    /// where more game-deciding points are played.
    private static func returnSides(_ a: DoublesProfile, _ b: DoublesProfile) -> (deuce: PlayerSlot, ad: PlayerSlot) {
        let sa = a.preferredSide, sb = b.preferredSide
        // Clear complementary or single preference.
        if sa == .deuce && sb != .deuce { return (.a, .b) }
        if sa == .ad && sb != .ad { return (.b, .a) }
        if sb == .deuce && sa != .deuce { return (.b, .a) }
        if sb == .ad && sa != .ad { return (.a, .b) }
        // Clash (both same fixed side) or both either → clutch to ad.
        return a.returnStrength >= b.returnStrength ? (.b, .a) : (.a, .b)
    }

    private static func startingFormation(_ a: DoublesProfile, _ b: DoublesProfile) -> StartingFormation {
        let pair = Set([a.netComfort, b.netComfort])
        if pair == [.net] { return .bothUp }
        if pair == [.baseline] { return .startBackApproach }
        return .oneUpOneBackPoach
    }
}
