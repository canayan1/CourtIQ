import Foundation

// Standalone validation harness for the two-axis doubles scorer.
// Compiled with the pure source files via swiftc (no Xcode/XCTest).

var passed = 0, failed = 0
func check(_ cond: Bool, _ label: String) {
    if cond { passed += 1 } else { failed += 1; print("  ❌ FAIL: \(label)") }
}

func P(_ side: DoublesSide, _ net: NetComfort, _ hand: Handedness, _ form: FormationComfort,
       _ serve: Int, _ ret: Int, _ comms: CommStyle, _ temp: Temperament, _ goal: DoublesGoal) -> DoublesProfile {
    DoublesProfile(preferredSide: side, netComfort: net, handedness: hand, formation: form,
                   serveStrength: serve, returnStrength: ret, comms: comms, temperament: temp, goal: goal)
}

// 1) Ideal pair: complementary tactically + great chemistry.
let aIdeal = P(.deuce, .net, .right, .flexible, 5, 4, .vocal, .calm, .win)
let bIdeal = P(.ad, .baseline, .left, .flexible, 4, 5, .vocal, .fiery, .win)
let rIdeal = DoublesCompatibility.score(aIdeal, bIdeal)
check(rIdeal.score >= 85, "ideal pair overall >=85 (got \(rIdeal.score))")
check(rIdeal.tacticalScore >= 85, "ideal tactical >=85 (got \(rIdeal.tacticalScore))")
check(rIdeal.chemistryScore >= 85, "ideal chemistry >=85 (got \(rIdeal.chemistryScore))")
check(rIdeal.band == .strong, "ideal band strong")
check(rIdeal.dimensions.count == 8, "8 dimensions (got \(rIdeal.dimensions.count))")
check(rIdeal.dimensions.filter { $0.dimension.axis == .tactical }.count == 5, "5 tactical dims")
check(rIdeal.dimensions.filter { $0.dimension.axis == .chemistry }.count == 3, "3 chemistry dims")

// 2) Great tactics, terrible chemistry → high tactical, low chemistry.
let aMix = P(.deuce, .net, .right, .flexible, 5, 5, .quiet, .fiery, .win)
let bMix = P(.ad, .baseline, .left, .flexible, 5, 5, .quiet, .fiery, .fun)
let rMix = DoublesCompatibility.score(aMix, bMix)
check(rMix.tacticalScore >= 85, "mix: tactical high (got \(rMix.tacticalScore))")
check(rMix.chemistryScore < 55, "mix: chemistry low (got \(rMix.chemistryScore))")
check(rMix.dimension(.comms)?.rating == .red, "mix: both quiet → comms red")
check(rMix.dimension(.temperament)?.rating == .red, "mix: both fiery → temperament red")
check(rMix.dimension(.goal)?.rating == .red, "mix: win+fun → goal red")
check(rMix.tacticalScore > rMix.chemistryScore, "mix: tactical > chemistry")

// 3) Worst tactical: same fixed side, both baseline, same hand, standard, weak serves.
let aBad = P(.deuce, .baseline, .right, .standardOnly, 2, 2, .moderate, .balanced, .improve)
let bBad = P(.deuce, .baseline, .right, .standardOnly, 2, 2, .moderate, .balanced, .improve)
let rBad = DoublesCompatibility.score(aBad, bBad)
check(rBad.dimension(.courtSide)?.rating == .red, "bad: court-side clash red")
check(rBad.dimension(.netBaseline)?.rating == .red, "bad: both baseline red")
check(rBad.tacticalScore < 55, "bad: tactical low (got \(rBad.tacticalScore))")
check(rBad.chemistryScore >= 80, "bad: chemistry still fine (got \(rBad.chemistryScore))")

// 4) Chemistry: calm + fiery green; matched goal green.
check(rIdeal.dimension(.temperament)?.rating == .green, "calm+fiery temperament green")
check(rIdeal.dimension(.goal)?.rating == .green, "same goal green")

// 5) Recommendations.
check(rIdeal.serveFirst == .a, "stronger server A serves first (5 vs 4)")
let aClash = P(.deuce, .net, .right, .flexible, 3, 5, .vocal, .calm, .win)
let bClash = P(.deuce, .mixed, .left, .flexible, 3, 2, .vocal, .calm, .win)
let rClash = DoublesCompatibility.score(aClash, bClash)
check(rClash.adReturner == .a && rClash.deuceReturner == .b, "clash: higher returnStrength (A) to ad")
check(DoublesCompatibility.score(
    P(.deuce, .net, .right, .flexible, 4, 4, .vocal, .calm, .win),
    P(.ad, .net, .left, .flexible, 4, 4, .vocal, .calm, .win)).startingFormation == .bothUp, "both net → bothUp")

// 6) Symmetry + determinism + Codable.
check(rIdeal.score == DoublesCompatibility.score(bIdeal, aIdeal).score, "overall score symmetric")
check(DoublesCompatibility.score(aIdeal, bIdeal) == DoublesCompatibility.score(aIdeal, bIdeal), "deterministic")
let enc = JSONEncoder(); let dec = JSONDecoder()
check((try? dec.decode(DoublesProfile.self, from: enc.encode(aIdeal))) == aIdeal, "DoublesProfile round-trips")
check((try? dec.decode(DoublesResult.self, from: enc.encode(rIdeal))) == rIdeal, "DoublesResult round-trips")

print("\nDoubles scorer: \(passed) passed, \(failed) failed")
if failed > 0 { exit(1) }
print("ideal: overall=\(rIdeal.score) tac=\(rIdeal.tacticalScore) chem=\(rIdeal.chemistryScore) band=\(rIdeal.band)")
print("tac-good/chem-bad: overall=\(rMix.score) tac=\(rMix.tacticalScore) chem=\(rMix.chemistryScore)")
print("tac-bad/chem-good: overall=\(rBad.score) tac=\(rBad.tacticalScore) chem=\(rBad.chemistryScore)")
