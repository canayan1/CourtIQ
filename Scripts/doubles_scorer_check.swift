import Foundation

// Standalone validation harness for the doubles scorer.
// Compiled with the 3 pure source files via swiftc (no Xcode/XCTest).

var passed = 0, failed = 0
func check(_ cond: Bool, _ label: String) {
    if cond { passed += 1 } else { failed += 1; print("  ❌ FAIL: \(label)") }
}

// Helpers to build profiles tersely.
func P(_ side: DoublesSide, _ net: NetComfort, _ poach: PoachTendency,
       _ comms: CommStyle, _ pressure: PressureStyle, _ form: FormationComfort,
       _ hand: Handedness, _ serve: Int, _ ret: Int) -> DoublesProfile {
    DoublesProfile(preferredSide: side, netComfort: net, poach: poach, comms: comms,
                   pressure: pressure, formation: form, handedness: hand,
                   serveStrength: serve, returnStrength: ret)
}

// 1) Ideal pair: complementary sides, net+baseline balance, vocal, matched
//    pressure, both flexible, lefty+righty, strong serves.
let aIdeal = P(.deuce, .net, .aggressive, .vocal, .goForIt, .flexible, .right, 5, 4)
let bIdeal = P(.ad,    .baseline, .selective, .vocal, .goForIt, .flexible, .left, 4, 5)
let rIdeal = DoublesCompatibility.score(aIdeal, bIdeal)
check(rIdeal.score >= 80, "ideal pair scores >=80 (got \(rIdeal.score))")
check(rIdeal.band == .strong, "ideal pair band == strong (got \(rIdeal.band))")
check(rIdeal.dimensions.count == 7, "7 dimensions present (got \(rIdeal.dimensions.count))")
check(Set(rIdeal.dimensions.map { $0.dimension }).count == DoublesDimension.allCases.count, "all dimensions covered once")

// 2) Worst pair: both fixed-same side, both baseline-only, both quiet,
//    opposite pressure, standard-only, same hand, weak serves.
let aBad = P(.deuce, .baseline, .holds, .quiet, .goForIt, .standardOnly, .right, 2, 2)
let bBad = P(.deuce, .baseline, .holds, .quiet, .defend,  .standardOnly, .right, 2, 2)
let rBad = DoublesCompatibility.score(aBad, bBad)
check(rBad.score < 60, "worst pair scores <60 (got \(rBad.score))")
check(rBad.band == .needsPlan, "worst pair band == needsPlan (got \(rBad.band))")
// court-side should be red (both deuce)
check(rBad.dimensions.first { $0.dimension == .courtSide }?.rating == .red, "court-side clash is red")
check(rBad.dimensions.first { $0.dimension == .netBaseline }?.rating == .red, "both baseline is red")
check(rBad.dimensions.first { $0.dimension == .comms }?.rating == .red, "both quiet is red")
check(rBad.watchOutKeys.contains(.courtSide) || rBad.watchOutKeys.contains(.netBaseline), "watch-outs surface a red")

// 3) Score symmetry (order shouldn't change the numeric score).
check(rIdeal.score == DoublesCompatibility.score(bIdeal, aIdeal).score, "score is symmetric")

// 4) Determinism.
check(DoublesCompatibility.score(aIdeal, bIdeal) == DoublesCompatibility.score(aIdeal, bIdeal), "deterministic")

// 5) Handedness: lefty+righty green; same yellow.
check(rIdeal.dimensions.first { $0.dimension == .handedness }?.rating == .green, "lefty+righty handedness green")
check(rBad.dimensions.first { $0.dimension == .handedness }?.rating == .yellow, "same-hand handedness yellow")

// 6) Serve order: higher serveStrength serves first. aIdeal=5 vs bIdeal=4 → A.
check(rIdeal.serveFirst == .a, "stronger server (A) serves first")
let rServe = DoublesCompatibility.score(
    P(.either, .mixed, .selective, .moderate, .percentage, .flexible, .right, 2, 3),
    P(.either, .mixed, .selective, .moderate, .percentage, .flexible, .right, 5, 3))
check(rServe.serveFirst == .b, "stronger server (B) serves first")

// 7) Return-side clash: both want deuce → higher returnStrength takes ad.
let aClash = P(.deuce, .net, .selective, .vocal, .percentage, .flexible, .right, 3, 5)
let bClash = P(.deuce, .mixed, .selective, .vocal, .percentage, .flexible, .left, 3, 2)
let rClash = DoublesCompatibility.score(aClash, bClash)
check(rClash.adReturner == .a, "clash: higher returnStrength (A) takes ad")
check(rClash.deuceReturner == .b, "clash: B takes deuce")

// 8) Formation recommendation: both net → bothUp; both baseline → startBack.
check(DoublesCompatibility.score(
    P(.deuce, .net, .aggressive, .vocal, .goForIt, .flexible, .right, 4, 4),
    P(.ad, .net, .aggressive, .vocal, .goForIt, .flexible, .left, 4, 4)).startingFormation == .bothUp,
    "both net → bothUp formation")
check(rBad.startingFormation == .startBackApproach, "both baseline → startBackApproach")

// 9) Codable round-trip (wire format integrity for MC / invite link).
let enc = JSONEncoder(); let dec = JSONDecoder()
let data = try! enc.encode(aIdeal)
let back = try! dec.decode(DoublesProfile.self, from: data)
check(back == aIdeal, "DoublesProfile Codable round-trips")
let rdata = try! enc.encode(rIdeal)
let rback = try! dec.decode(DoublesResult.self, from: rdata)
check(rback == rIdeal, "DoublesResult Codable round-trips")

print("\nDoubles scorer: \(passed) passed, \(failed) failed")
if failed > 0 { exit(1) }
print("Sample — ideal pair: score=\(rIdeal.score) band=\(rIdeal.band) serveFirst=\(rIdeal.serveFirst) ad=\(rIdeal.adReturner) formation=\(rIdeal.startingFormation)")
print("Sample — worst pair: score=\(rBad.score) band=\(rBad.band) watchOuts=\(rBad.watchOutKeys.map{$0.rawValue})")
