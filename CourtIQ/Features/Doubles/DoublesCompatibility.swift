import Foundation

/// Deterministic doubles compatibility scorer. Pure function of two
/// `DoublesProfile`s → a `DoublesResult` with TWO axis sub-scores
/// (tactical + chemistry) and an overall. No app/UI deps, no randomness.
/// Encodes standard doubles strategy + partnership-chemistry heuristics
/// (see docs/FEATURE_SPEC_doubles_v1.1.md).
enum DoublesCompatibility {

    // Weights within each axis (each axis sums to 100).
    private static let tacticalWeights: [DoublesDimension: Double] = [
        .courtSide: 30, .netBaseline: 30, .handedness: 18, .formation: 12, .serve: 10,
    ]
    private static let chemistryWeights: [DoublesDimension: Double] = [
        .comms: 35, .temperament: 35, .goal: 30,
    ]

    static func score(_ a: DoublesProfile, _ b: DoublesProfile) -> DoublesResult {
        let tactical: [DimensionScore] = [
            courtSide(a, b), netBaseline(a, b), handedness(a, b), formation(a, b), serve(a, b),
        ]
        let chemistry: [DimensionScore] = [
            comms(a, b), temperament(a, b), goal(a, b),
        ]

        let tacticalScore = axisScore(tactical, tacticalWeights)
        let chemistryScore = axisScore(chemistry, chemistryWeights)
        let overall = Int(((Double(tacticalScore) + Double(chemistryScore)) / 2.0).rounded())
        let band: CompatBand = overall >= 80 ? .strong : (overall >= 60 ? .workable : .needsPlan)

        let all = tactical + chemistry
        let weightOf: (DoublesDimension) -> Double = {
            (tacticalWeights[$0] ?? chemistryWeights[$0] ?? 0)
        }
        let byWeightDesc: (DimensionScore, DimensionScore) -> Bool = {
            weightOf($0.dimension) > weightOf($1.dimension)
        }
        let strengths = all.filter { $0.rating == .green }.sorted(by: byWeightDesc).map { $0.dimension }
        let reds = all.filter { $0.rating == .red }.sorted(by: byWeightDesc)
        let yellows = all.filter { $0.rating == .yellow }.sorted(by: byWeightDesc)
        let watchOuts = (reds + yellows).map { $0.dimension }

        let (deuce, ad) = returnSides(a, b)
        return DoublesResult(
            score: overall,
            tacticalScore: tacticalScore,
            chemistryScore: chemistryScore,
            band: band,
            dimensions: all,
            serveFirst: a.serveStrength >= b.serveStrength ? .a : .b,
            deuceReturner: deuce,
            adReturner: ad,
            startingFormation: startingFormation(a, b),
            strengthKeys: Array(strengths.prefix(3)),
            watchOutKeys: Array(watchOuts.prefix(3))
        )
    }

    private static func axisScore(_ dims: [DimensionScore], _ weights: [DoublesDimension: Double]) -> Int {
        var weighted = 0.0, total = 0.0
        for d in dims {
            let w = weights[d.dimension] ?? 0
            weighted += d.sub * w
            total += w
        }
        return total > 0 ? Int((weighted / total * 100).rounded()) : 0
    }

    // MARK: - Tactical dimensions

    private static func courtSide(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        let sa = a.preferredSide, sb = b.preferredSide
        let sub: Double; let r: DimensionRating
        if sa == .either && sb == .either { sub = 0.8; r = .yellow }
        else if sa == .either || sb == .either { sub = 1.0; r = .green }
        else if sa != sb { sub = 1.0; r = .green }
        else { sub = 0.2; r = .red }
        return DimensionScore(dimension: .courtSide, rating: r, sub: sub)
    }

    private static func netBaseline(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        let pair = Set([a.netComfort, b.netComfort])
        let sub: Double; let r: DimensionRating
        if pair == [.baseline] { sub = 0.3; r = .red }
        else if pair == [.net] { sub = 0.6; r = .yellow }
        else if pair == [.mixed] { sub = 0.85; r = .green }
        else if pair.contains(.net) { sub = 1.0; r = .green }
        else { sub = 0.7; r = .yellow }
        return DimensionScore(dimension: .netBaseline, rating: r, sub: sub)
    }

    private static func handedness(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        a.handedness != b.handedness
            ? DimensionScore(dimension: .handedness, rating: .green, sub: 1.0)
            : DimensionScore(dimension: .handedness, rating: .yellow, sub: 0.7)
    }

    private static func formation(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        let flex = [a.formation, b.formation].filter { $0 == .flexible }.count
        switch flex {
        case 2:  return DimensionScore(dimension: .formation, rating: .green, sub: 1.0)
        case 1:  return DimensionScore(dimension: .formation, rating: .yellow, sub: 0.7)
        default: return DimensionScore(dimension: .formation, rating: .yellow, sub: 0.5)
        }
    }

    private static func serve(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        let avg = Double(a.serveStrength + b.serveStrength) / 2.0
        let sub = max(0.0, min(1.0, (avg - 1.0) / 4.0))
        let r: DimensionRating = avg >= 3.5 ? .green : (avg >= 2.5 ? .yellow : .red)
        return DimensionScore(dimension: .serve, rating: r, sub: sub)
    }

    // MARK: - Chemistry dimensions

    private static func comms(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        let pair = Set([a.comms, b.comms])
        let sub: Double; let r: DimensionRating
        if pair == [.quiet] { sub = 0.3; r = .red }
        else if pair.contains(.quiet) { sub = 0.6; r = .yellow }
        else if pair == [.vocal] { sub = 1.0; r = .green }
        else { sub = 0.85; r = .green }
        return DimensionScore(dimension: .comms, rating: r, sub: sub)
    }

    /// One calm anchor steadies a fiery partner; two fiery players are
    /// volatile under pressure.
    private static func temperament(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        let pair = Set([a.temperament, b.temperament])
        let sub: Double; let r: DimensionRating
        if pair == [.fiery] { sub = 0.4; r = .red }                      // both hotheads
        else if pair == [.calm, .fiery] { sub = 1.0; r = .green }        // anchor balances fire
        else if pair == [.fiery] || pair.contains(.fiery) { sub = 0.7; r = .yellow } // balanced+fiery
        else if pair == [.calm] { sub = 0.9; r = .green }
        else { sub = 0.9; r = .green }                                   // calm+balanced / both balanced
        return DimensionScore(dimension: .temperament, rating: r, sub: sub)
    }

    /// Goal mismatch (one wants to win, one's here for fun) is a real
    /// source of partnership friction.
    private static func goal(_ a: DoublesProfile, _ b: DoublesProfile) -> DimensionScore {
        func rank(_ g: DoublesGoal) -> Int {
            switch g { case .win: return 2; case .improve: return 1; case .fun: return 0 }
        }
        let gap = abs(rank(a.goal) - rank(b.goal))
        switch gap {
        case 0:  return DimensionScore(dimension: .goal, rating: .green, sub: 1.0)
        case 1:  return DimensionScore(dimension: .goal, rating: .yellow, sub: 0.7)
        default: return DimensionScore(dimension: .goal, rating: .red, sub: 0.35)
        }
    }

    // MARK: - Derived recommendations

    private static func returnSides(_ a: DoublesProfile, _ b: DoublesProfile) -> (deuce: PlayerSlot, ad: PlayerSlot) {
        let sa = a.preferredSide, sb = b.preferredSide
        if sa == .deuce && sb != .deuce { return (.a, .b) }
        if sa == .ad && sb != .ad { return (.b, .a) }
        if sb == .deuce && sa != .deuce { return (.b, .a) }
        if sb == .ad && sa != .ad { return (.a, .b) }
        return a.returnStrength >= b.returnStrength ? (.b, .a) : (.a, .b)
    }

    private static func startingFormation(_ a: DoublesProfile, _ b: DoublesProfile) -> StartingFormation {
        let pair = Set([a.netComfort, b.netComfort])
        if pair == [.net] { return .bothUp }
        if pair == [.baseline] { return .startBackApproach }
        return .oneUpOneBackPoach
    }
}
