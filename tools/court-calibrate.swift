// Turn a clip into a court ruler, and say how good the ruler is.
//
//   swiftc -O tools/court-calibrate.swift \
//          CourtIQ/Features/Duel/CourtCalibration.swift \
//          CourtIQ/Features/Duel/CourtLineFinder.swift -o /tmp/court-calibrate
//   /tmp/court-calibrate <video> [out.png]
//
// The analysis types are the app's own files, compiled in — this driver only
// supplies frames and prints. Whatever it reports here is what the app gets.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let argv = CommandLine.arguments
guard argv.count >= 2 else { print("usage: court-calibrate <video> [out.png]"); exit(1) }
let url = URL(fileURLWithPath: argv[1])

let clip: Clip
do { clip = try Clip.read(url: url) }
catch { print(error.localizedDescription); exit(1) }
let W = clip.width, H = clip.height
let background = clip.background
print(String(format: "%dx%d, %.1f s — background from %d frames",
             W, H, clip.duration, clip.backgroundFrames))

let band = CourtLineFinder.playBand(motionCount: clip.motionCount, width: W, height: H)
print("play band: rows \(band.lowerBound)..\(band.upperBound) of \(H)")
let mask = CourtLineFinder.ridgeMask(gray: background, width: W, height: H, rows: band)
let lines = CourtLineFinder.acrossLines(mask: mask, width: W, height: H, rows: band)
print("\nlines across the court, nearest first:")
for l in lines {
    print(String(format: "   row %6.0f  support %4d px  slope %+.3f  spans x %d..%d",
                 l.yAtCentre, l.support, l.slope, l.xStart, l.xEnd))
}

guard let raw = CourtCalibration.solve(from: lines) else {
    print("\nno court model fits these lines — analysis must fall back to body heights")
    exit(2)
}
// Derived sidelines are free evidence. Check the paint is really under them
// before letting anything downstream quote metres.
let support = raw.sidelineSupport(mask: mask, width: W, height: H)
let cal = raw.verified(mask: mask, width: W, height: H)
print(String(format: "\npaint found under the model — across %.0f%%, sidelines %.0f%%",
             raw.acrossSupport(mask: mask, width: W, height: H) * 100, support * 100))
if cal.confidence != raw.confidence {
    print("  -> demoted from \(raw.confidence.rawValue) to \(cal.confidence.rawValue)")
}
print("calibration: \(cal.confidence.rawValue)")
print("  anchored on " + cal.anchors.map { "\($0.name)@\(Int($0.1))" }.joined(separator: ", "))
print(String(format: "  mean miss over the lines it explains: %.2f px", cal.residual))
print("  every court line, where the model puts it:")
for (name, d) in CourtSpec.acrossDepths {
    print(String(format: "    %-18@ %6.3f m -> row %7.1f", name as NSString, d, cal.imageY(atDepth: d)))
}
if cal.confidence == .full {
    print("\n  one pixel is worth, in centimetres of court:")
    for d in [0.0, CourtSpec.baselineToNet, CourtSpec.baselineToBaseline] {
        let p = cal.precisionCm(atDepth: d)
        print(String(format: "    %6.2f m away: %5.1f cm across, %6.1f cm deep", d, p.across, p.deep))
    }
}

// Draw the whole court model back over the clip. If the sidelines — which are
// never detected, only derived — land on the real ones, the solve is right.
guard argv.count >= 3, let ov = Overlay(background: background, width: W, height: H)
else { exit(0) }
if cal.confidence == .full {
    for (_, d) in CourtSpec.acrossDepths {
        let half = (d == 0 || d == CourtSpec.baselineToNet || d == CourtSpec.baselineToBaseline)
            ? CourtSpec.doublesHalfWidth : CourtSpec.singlesHalfWidth
        ov.line(cal.pixel(for: CourtPoint(across: -half, depth: d)),
                cal.pixel(for: CourtPoint(across: half, depth: d)), (1, 0, 0.8))
    }
    for x in [-CourtSpec.doublesHalfWidth, -CourtSpec.singlesHalfWidth,
              CourtSpec.singlesHalfWidth, CourtSpec.doublesHalfWidth] {
        ov.line(cal.pixel(for: CourtPoint(across: x, depth: 0)),
                cal.pixel(for: CourtPoint(across: x, depth: CourtSpec.baselineToBaseline)),
                (0, 0.85, 1))
    }
    ov.line(cal.pixel(for: CourtPoint(across: 0, depth: CourtSpec.baselineToServiceLine)),
            cal.pixel(for: CourtPoint(across: 0,
                                      depth: CourtSpec.baselineToBaseline - CourtSpec.baselineToServiceLine)),
            (0, 0.85, 1))
}
ov.write(to: URL(fileURLWithPath: argv[2]))
print("\nwrote \(argv[2])")
