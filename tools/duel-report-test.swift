// Checks the one thing in the duel report that can be silently backwards.
//
//   swiftc -O tools/duel-report-test.swift CourtIQ/Features/Duel/*.swift -o /tmp/t && /tmp/t
//
// A right-hander's forehand sits on the right of the IMAGE when they have
// their back to the camera and on the LEFT of it when they face the camera.
// Every wing in the report depends on that flip, no real clip on hand has two
// players to catch it, and a mirrored report reads perfectly plausible. So it
// is tested against a synthetic track whose answer is known by construction.

import Foundation

var failures = 0
func expect(_ condition: Bool, _ what: String) {
    print((condition ? "  ok   " : "  FAIL ") + what)
    if !condition { failures += 1 }
}

/// A player who stands 1.5 m behind their baseline for every ball met on the
/// LEFT of the image and 0.5 m behind it for every ball on the right.
func syntheticTrack(end: PlayerTrack.End) -> (PlayerTrack, [Double]) {
    let baseline = end == .near ? 0.0 : CourtSpec.baselineToBaseline
    let sign: Double = end == .near ? -1 : 1       // "behind" is away from the net
    var samples: [PlayerSample] = []
    var impacts: [Double] = []
    var t = 0.0
    var onLeft = true
    while t < 48 {
        let across = onLeft ? -2.0 : 2.0
        let behind = onLeft ? 1.5 : 0.5
        let depth = baseline + sign * behind
        // Dense enough that position() and speed() have something to read.
        for k in 0..<12 {
            samples.append(PlayerSample(time: t + Double(k) * 0.1,
                                        court: CourtPoint(across: across, depth: depth),
                                        pixelHeight: 100,
                                        footPixel: .zero))
        }
        impacts.append(t + 0.6)
        t += 1.2
        onLeft.toggle()
    }
    return (PlayerTrack(end: end, samples: samples), impacts)
}

print("wing naming, right-handed:")
for (end, expected) in [(PlayerTrack.End.near, "backhand"), (.far, "forehand")] {
    let (track, impacts) = syntheticTrack(end: end)
    let player = DuelPlayer(number: .one, end: end, handedness: .right)
    let split = DuelReport.wings(track, impacts: impacts, player: player)
    let lines = DuelReport.sentences(for: player, wings: split, precisionCm: 3)
    let depthLine = lines.first { $0.contains("behind the") } ?? "(no depth sentence)"
    // Constructed so the deeper side is the image's left. For the near player
    // that is the backhand side; for the far player, facing the camera, the
    // same patch of court is their forehand side.
    expect(depthLine.contains(expected),
           "\(end.rawValue) player, deeper on image-left -> \(expected) side")
    print("       \(depthLine)")
}

print("\nleft-handed mirrors it:")
for (end, expected) in [(PlayerTrack.End.near, "forehand"), (.far, "backhand")] {
    let (track, impacts) = syntheticTrack(end: end)
    let player = DuelPlayer(number: .one, end: end, handedness: .left)
    let split = DuelReport.wings(track, impacts: impacts, player: player)
    let lines = DuelReport.sentences(for: player, wings: split, precisionCm: 3)
    let depthLine = lines.first { $0.contains("behind the") } ?? "(no depth sentence)"
    expect(depthLine.contains(expected), "\(end.rawValue) player, left-handed -> \(expected) side")
}

print("\nrefusals:")
let (track, impacts) = syntheticTrack(end: .near)
let unknown = DuelPlayer(number: .one, end: .near, handedness: .unknown)
let noHand = DuelReport.sentences(for: unknown,
                                  wings: DuelReport.wings(track, impacts: impacts, player: unknown),
                                  precisionCm: 3)
expect(noHand.count == 1 && noHand[0].contains("which hand"),
       "no handedness -> asks instead of guessing a wing")

let righty = DuelPlayer(number: .one, end: .near, handedness: .right)
let fewImpacts = Array(impacts.prefix(6))
let short = DuelReport.sentences(for: righty,
                                 wings: DuelReport.wings(track, impacts: fewImpacts, player: righty),
                                 precisionCm: 3)
expect(short.count == 1 && short[0].contains("too few"),
       "six strokes -> refuses to compare the sides")

// At the far baseline a pixel is worth 40 cm, so a 30 cm difference there is
// the clip's resolution, not the player.
let coarse = DuelReport.sentences(for: righty,
                                  wings: DuelReport.wings(track, impacts: impacts, player: righty),
                                  precisionCm: 40)
expect(!coarse.contains { $0.contains("behind the") },
       "1.0 m gap at 40 cm/pixel -> not claimed")

print("\nlabels:")
expect(DuelPlayer(number: .one, end: .near, handedness: .right).label
       == "Player 1, nearest the camera", "player 1 says where they stood")
expect(DuelPlayer(number: .two, end: .far, handedness: .right).label
       == "Player 2, across the net", "player 2 says where they stood")

print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
