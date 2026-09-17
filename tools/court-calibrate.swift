// Turn a clip into a court ruler, and say how good the ruler is.
//
//   swiftc -O tools/court-calibrate.swift \
//          CourtIQ/Features/Duel/CourtCalibration.swift \
//          CourtIQ/Features/Duel/CourtLineFinder.swift -o /tmp/court-calibrate
//   /tmp/court-calibrate <video> [out.png]
//
// The analysis types are the app's own files, compiled in — this driver only
// supplies frames and prints. Whatever it reports here is what the app gets.

import AVFoundation
import CoreImage
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let argv = CommandLine.arguments
guard argv.count >= 2 else { print("usage: court-calibrate <video> [out.png]"); exit(1) }
let url = URL(fileURLWithPath: argv[1])

let asset = AVURLAsset(url: url)
guard let track = asset.tracks(withMediaType: .video).first else { print("no video track"); exit(1) }

// Rotation lives in preferredTransform, never in the pixels. Ignoring it is
// how duel-eval spent a calibration run analysing sideways people.
let xf = track.preferredTransform
let display = track.naturalSize.applying(xf)
let W = Int(abs(display.width).rounded()), H = Int(abs(display.height).rounded())
let ctx = CIContext(options: [.useSoftwareRenderer: false])
let rotation: CGFloat
switch (xf.a.rounded(), xf.b.rounded(), xf.c.rounded(), xf.d.rounded()) {
case (0, 1, -1, 0):  rotation = -.pi / 2
case (0, -1, 1, 0):  rotation = .pi / 2
case (-1, 0, 0, -1): rotation = .pi
default:             rotation = 0
}

let fps = 5.0
let step = max(1, Int((Double(track.nominalFrameRate) / fps).rounded()))
let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(output)
reader.startReading()

var frames: [[Float]] = []
var index = 0
while let sample = output.copyNextSampleBuffer() {
    defer { index += 1 }
    guard index % step == 0, let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
    var image = CIImage(cvPixelBuffer: buffer)
    if rotation != 0 { image = image.transformed(by: CGAffineTransform(rotationAngle: rotation)) }
    image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX,
                                                    y: -image.extent.minY))
    guard let cg = ctx.createCGImage(image, from: CGRect(x: 0, y: 0, width: W, height: H))
    else { continue }
    var bytes = [UInt8](repeating: 0, count: W * H * 4)
    guard let bmp = CGContext(data: &bytes, width: W, height: H, bitsPerComponent: 8,
                              bytesPerRow: W * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { continue }
    bmp.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
    var grey = [Float](repeating: 0, count: W * H)
    for i in 0..<(W * H) {
        grey[i] = 0.299 * Float(bytes[i * 4]) + 0.587 * Float(bytes[i * 4 + 1])
                + 0.114 * Float(bytes[i * 4 + 2])
    }
    frames.append(grey)
}
guard frames.count >= 8 else { print("only \(frames.count) frames — too short to calibrate"); exit(1) }
print("\(frames.count) frames of \(W)x\(H)")

// The background is the per-pixel median over the clip, which is the court
// with the players removed — the cleanest view of the lines the clip contains.
var background = [Float](repeating: 0, count: W * H)
var motion = [Int](repeating: 0, count: W * H)
var column = [Float](repeating: 0, count: frames.count)
for i in 0..<(W * H) {
    for (j, f) in frames.enumerated() { column[j] = f[i] }
    column.sort()
    background[i] = column[column.count / 2]
}
for f in frames {
    for i in 0..<(W * H) where abs(f[i] - background[i]) > 22 { motion[i] += 1 }
}

let band = CourtLineFinder.playBand(motionCount: motion, width: W, height: H)
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
guard argv.count >= 3 else { exit(0) }
let out = URL(fileURLWithPath: argv[2])
guard let draw = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                           space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
for y in 0..<H {
    for x in 0..<W {
        let v = background[y * W + x] / 255
        draw.setFillColor(red: CGFloat(v), green: CGFloat(v), blue: CGFloat(v), alpha: 1)
        draw.fill(CGRect(x: x, y: H - 1 - y, width: 1, height: 1))
    }
}
func stroke(_ p0: CourtPoint, _ p1: CourtPoint, _ rgb: (CGFloat, CGFloat, CGFloat)) {
    let a = cal.pixel(for: p0), b = cal.pixel(for: p1)
    draw.setStrokeColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    draw.setLineWidth(2)
    draw.move(to: CGPoint(x: a.x, y: CGFloat(H) - a.y))
    draw.addLine(to: CGPoint(x: b.x, y: CGFloat(H) - b.y))
    draw.strokePath()
}
if cal.confidence == .full {
    for (_, d) in CourtSpec.acrossDepths {
        let half = (d == 0 || d == CourtSpec.baselineToNet || d == CourtSpec.baselineToBaseline)
            ? CourtSpec.doublesHalfWidth : CourtSpec.singlesHalfWidth
        stroke(CourtPoint(across: -half, depth: d), CourtPoint(across: half, depth: d), (1, 0, 0.8))
    }
    for x in [-CourtSpec.doublesHalfWidth, -CourtSpec.singlesHalfWidth,
              CourtSpec.singlesHalfWidth, CourtSpec.doublesHalfWidth] {
        stroke(CourtPoint(across: x, depth: 0),
               CourtPoint(across: x, depth: CourtSpec.baselineToBaseline), (0, 0.85, 1))
    }
    stroke(CourtPoint(across: 0, depth: CourtSpec.baselineToServiceLine),
           CourtPoint(across: 0, depth: CourtSpec.baselineToBaseline - CourtSpec.baselineToServiceLine),
           (0, 0.85, 1))
}
if let img = draw.makeImage(),
   let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) {
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    print("\nwrote \(out.path)")
}
