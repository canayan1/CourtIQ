// The full offline pipeline: calibrate the court, then track both players on
// it in metres.
//
//   swiftc -O tools/duel-track.swift tools/ClipReader.swift \
//          CourtIQ/Features/Duel/*.swift -o /tmp/duel-track
//   /tmp/duel-track <video> [out.png]
//
// (Compile with the driver copied to main.swift; Swift wants the entry point
// in a file of that name when several are given.)

import CoreGraphics
import Foundation

let argv = CommandLine.arguments
guard argv.count >= 2 else { print("usage: duel-track <video> [out.png] [fps]"); exit(1) }
let videoURL = URL(fileURLWithPath: argv[1])
// 10 fps is where the per-stroke numbers stop changing: at 5 fps the half
// second of smoothing has only two or three samples to work with, while 10 fps
// and 15 fps agree to the last printed digit on every metric.
let sampleFPS = argv.count >= 4 ? (Double(argv[3]) ?? 10) : 10

let clip: Clip
do { clip = try Clip.read(url: videoURL) }
catch { print(error.localizedDescription); exit(1) }
let W = clip.width, H = clip.height
print(String(format: "%dx%d, %.1f s — background from %d frames, tracking at %d fps",
             W, H, clip.duration, clip.backgroundFrames, Int(sampleFPS)))

let band = CourtLineFinder.playBand(motionCount: clip.motionCount, width: W, height: H)
let ridge = CourtLineFinder.ridgeMask(gray: clip.background, width: W, height: H, rows: band)
let lines = CourtLineFinder.acrossLines(mask: ridge, width: W, height: H, rows: band)
guard let raw = CourtCalibration.solve(from: lines) else {
    print("no court model fits this clip — nothing here can be quoted in metres"); exit(2)
}
let cal = raw.verified(mask: ridge, width: W, height: H)
print("calibration: \(cal.confidence.rawValue)"
      + String(format: "  (mean miss %.2f px)", cal.residual))
guard cal.confidence == .full else {
    print("without lateral metres there is no fair comparison between the ends —")
    print("analysis must fall back to body heights and say so.")
    exit(3)
}

// Track. Blobs are searched across the whole frame, not just the play band:
// the band exists to find the lines, and a player chasing a wide ball can
// leave it.
var tracks: [PlayerTrack] = []
do {
    var near: [PlayerSample] = [], far: [PlayerSample] = []
    var lastNear: CourtPoint? = nil, lastFar: CourtPoint? = nil
    try clip.forEachMask(fps: sampleFPS) { t, mask in
        let found = PlayerTracker.tracks(frameMasks: [(t, mask)], width: W, height: H,
                                         rows: 0..<H, calibration: cal,
                                         lastNear: &lastNear, lastFar: &lastFar)
        for f in found {
            if f.end == .near { near.append(contentsOf: f.samples) }
            else { far.append(contentsOf: f.samples) }
        }
    }
    if !near.isEmpty { tracks.append(PlayerTrack(end: .near, samples: near)) }
    if !far.isEmpty { tracks.append(PlayerTrack(end: .far, samples: far)) }
} catch { print(error.localizedDescription); exit(1) }
let sampledFrames = tracks.map(\.samples.count).max() ?? 0

print("\ntracks: \(tracks.map { "\($0.end.rawValue) (\($0.samples.count) frames)" }.joined(separator: ", "))")
for t in tracks {
    let depth = t.samples.map(\.court.depth).sorted()
    let across = t.samples.map(\.court.across).sorted()
    let heights = t.samples.map(\.pixelHeight).sorted()
    print("\n\(t.end.rawValue) end — seen in \(t.samples.count) of ~\(sampledFrames) frames")
    print(String(format: "  depth   median %5.2f m   range %5.2f .. %5.2f m",
                 depth[depth.count/2], depth.first!, depth.last!))
    print(String(format: "  across  median %+5.2f m   range %+5.2f .. %+5.2f m",
                 across[across.count/2], across.first!, across.last!))
    print(String(format: "  blob height median %4.0f px", heights[heights.count/2]))
    let partial = t.samples.filter(\.partial).count
    if partial > 0 {
        print(String(format: "  only partly visible in %d of %d frames — lateral position holds,"
                     + " depth does not", partial, t.samples.count))
    }
    let p = cal.precisionCm(atDepth: depth[depth.count/2])
    print(String(format: "  one pixel there is %.1f cm across, %.1f cm deep", p.across, p.deep))
}


// ── strokes ──────────────────────────────────────────────────────────────
// The audio finds impacts; the court decides whose they are. An impact only
// counts for a player who was actually tracked on their own half at that
// instant, which is the rejecting the person gate used to do and cannot do
// here — pose fails for the far player, so gating on it would silently delete
// one player's strokes.
let impacts = await BallImpactAudio.impacts(videoURL: videoURL,
                                           minGap: BallImpactAudio.rallyMinGap) ?? []
print("\naudio impacts: \(impacts.count)")

if tracks.count < 2 {
    print("only one player is on this court, so there is no head-to-head to report.")
    print("what follows measures that player alone.")
}

// Numbering is by end of court, which is the one thing about a player that
// stays true for the whole clip without recognising anybody — and the one
// thing the viewer can check at a glance.
let handed = ProcessInfo.processInfo.environment["HAND"].map {
    Handedness(rawValue: $0) ?? .unknown } ?? .unknown
let players = tracks.enumerated().map { i, t in
    DuelPlayer(number: i == 0 ? .one : .two, end: t.end, handedness: handed)
}

for (t, player) in zip(tracks, players) {
    let own = impacts.filter { DuelMetrics.position(t, at: $0) != nil }
    guard t.isMeasurable else {
        print(String(format: "\n%@ — visible in %d frames but only ever in pieces (%.0f%%).",
                     player.label, t.samples.count, t.partialShare * 100))
        print("  Nothing about them is measured from this clip: the lowest visible")
        print("  pixel of a half-seen player is not a foot, so every number built on")
        print("  it would be invented. This is what the shooting guide's height and")
        print("  resolution are for.")
        continue
    }
    guard let m = DuelMetrics.measure(t, impacts: own) else {
        print("\n\(player.label) — \(own.count) strokes in view, too few to measure")
        continue
    }
    print("\n\(player.label) — \(m.strokes) strokes")
    print(String(format: "  contact %+.2f m behind their own baseline", m.contactDepth))
    print(String(format: "  %.2f m travelled per stroke", m.metresPerStroke))
    print(String(format: "  still moving %.2f m/s at contact", m.speedAtContact))
    print(String(format: "  %.2f m off centre between strokes", m.recoveryGap))
    print(String(format: "  %.2f m of court width used", m.lateralSpread))

    let depth = t.samples.map(\.court.depth).sorted()
    let split = DuelReport.wings(t, impacts: own, player: player)
    for line in DuelReport.sentences(for: player, wings: split,
                                     precisionCm: cal.precisionCm(atDepth: depth[depth.count/2]).across) {
        print("  · " + line)
    }
}

if tracks.count == 2 {
    print("\nNOT REPORTED: which player hit each impact. Alternation and loudness")
    print("will decide it, and neither has been tested on a clip containing two")
    print("players — so pressure metrics stay unwritten rather than guessed.")
}

guard argv.count >= 3, let ov = Overlay(background: clip.background, width: W, height: H)
else { exit(0) }
for (_, d) in CourtSpec.acrossDepths {
    let half = (d == 0 || d == CourtSpec.baselineToNet || d == CourtSpec.baselineToBaseline)
        ? CourtSpec.doublesHalfWidth : CourtSpec.singlesHalfWidth
    ov.line(cal.pixel(for: CourtPoint(across: -half, depth: d)),
            cal.pixel(for: CourtPoint(across: half, depth: d)), (1, 0, 0.8), width: 1)
}
for x in [-CourtSpec.doublesHalfWidth, CourtSpec.doublesHalfWidth] {
    ov.line(cal.pixel(for: CourtPoint(across: x, depth: 0)),
            cal.pixel(for: CourtPoint(across: x, depth: CourtSpec.baselineToBaseline)),
            (0, 0.85, 1), width: 1)
}
for t in tracks {
    let colour: (CGFloat, CGFloat, CGFloat) = t.end == .near ? (0.2, 1, 0.3) : (1, 0.65, 0)
    for s in t.samples { ov.dot(s.footPixel, colour, r: 2) }
}
ov.write(to: URL(fileURLWithPath: argv[2]))
print("\nwrote \(argv[2])  — green feet are the near player, orange the far one")
