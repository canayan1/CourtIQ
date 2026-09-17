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
guard argv.count >= 2 else { print("usage: duel-track <video> [out.png]"); exit(1) }

let clip: Clip
do { clip = try Clip.read(url: URL(fileURLWithPath: argv[1])) }
catch { print(error.localizedDescription); exit(1) }
let W = clip.width, H = clip.height
print("\(clip.frames.count) frames of \(W)x\(H), \(String(format: "%.1f", clip.times.last ?? 0)) s")

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
var masks: [(time: Double, mask: [Bool])] = []
for i in clip.frames.indices { masks.append((clip.times[i], clip.motionMask(i))) }
let tracks = PlayerTracker.tracks(frameMasks: masks, width: W, height: H,
                                  rows: 0..<H, calibration: cal)

print("\ntracks: \(tracks.map { "\($0.end.rawValue) (\($0.samples.count) frames)" }.joined(separator: ", "))")
for t in tracks {
    let depth = t.samples.map(\.court.depth).sorted()
    let across = t.samples.map(\.court.across).sorted()
    let heights = t.samples.map(\.pixelHeight).sorted()
    print("\n\(t.end.rawValue) end — seen in \(t.samples.count) of \(clip.frames.count) frames")
    print(String(format: "  depth   median %5.2f m   range %5.2f .. %5.2f m",
                 depth[depth.count/2], depth.first!, depth.last!))
    print(String(format: "  across  median %+5.2f m   range %+5.2f .. %+5.2f m",
                 across[across.count/2], across.first!, across.last!))
    print(String(format: "  blob height median %4.0f px", heights[heights.count/2]))
    let p = cal.precisionCm(atDepth: depth[depth.count/2])
    print(String(format: "  one pixel there is %.1f cm across, %.1f cm deep", p.across, p.deep))
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
