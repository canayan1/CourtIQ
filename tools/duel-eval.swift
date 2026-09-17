#!/usr/bin/env swift
// Two players, one clip, one verdict — the measurement half, offline.
//
//   swift tools/duel-eval.swift <video> [fps]
//
// The rule this pipeline exists to respect (docs/SWING-ANALYSIS-RESEARCH.md §1):
// a video model cannot see motion. TimeBlind showed GPT-5 and Gemini 3 Pro
// cannot tell apart two clips that differ ONLY in movement, which is exactly
// forehand-vs-slice. So nothing here asks a model anything. Every number below
// comes from Vision body pose on this machine, and the verdict is arithmetic
// over those numbers. A model's only future job is to phrase the result.
//
// CALIBRATION, 17 Sep 2026 — READ THIS BEFORE BUILDING ON IT.
//
// The first calibration blamed the metrics. It was mostly wrong: two bugs in
// this file were corrupting the pose data underneath them.
//
//   1. The clip's rotation lives in preferredTransform, not in the pixel
//      buffer. Vision was being handed sideways people.
//   2. x is normalised against frame width and y against frame height, so on
//      a 9:16 frame the two were never the same unit, and every distance
//      mixing them was wrong.
//
// Fixing both roughly quintupled the usable frames — 15 of 198 to 169 on the
// ground-level clip, 146 of 235 to 842 on IMG_9933 — and with clean data four
// of the five metrics stopped depending on how often we looked. Same clip at
// 12 fps and 6 fps:
//
//      width of court used   2.79  vs  2.68     (4%)
//      widest base           0.86  vs  0.82     (5%)
//      time in a wide stance  51%  vs   52%     (1%)
//      highest wrist        +0.63  vs +0.63     (0%)
//      court coverage        5.92  vs 15.73   (166%)
//
// So: the four are reproducible and can carry a comparison. Court coverage is
// not, and no threshold will save it — accumulated travel counts steps, so it
// answers a question about the sampling rate, not about the player. It stays
// computed and clearly labelled below; replacing it means anchoring travel to
// the impacts SwingImpactAnalyzer already finds on the audio track and
// measuring displacement per stroke, which is a real number either way.
//
// STILL UNVALIDATED, AND THIS IS THE ONE THAT BLOCKS THE FEATURE: telling two
// people apart. Four clips have now gone through this file — a wall session
// from two angles, a court from a balcony, a court from the baseline — and
// not one frame of any of them contained two detectable people. Even at a
// confidence floor of 0.05, the player across the net is never found: in the
// baseline clip the near player is about 65 px tall and the far one roughly
// half that, and in the balcony clip the only other people in shot are on
// neighbouring courts. That is not a tuning problem. A phone filming from
// behind one baseline puts the opponent too far away to measure, so the
// association code below has still never run on the case it exists for.

import AVFoundation
import Vision
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: swift tools/duel-eval.swift <video> [fps]"); exit(1)
}
let url = URL(fileURLWithPath: args[1])
let targetFPS = args.count >= 3 ? Double(args[2]) ?? 12 : 12
let jointFloor: Float = 0.25

// ── per-frame pose harvest ───────────────────────────────────────────────

struct Person {
    var hip: CGPoint
    var wrist: CGPoint?
    var shoulderL: CGPoint?
    var shoulderR: CGPoint?
    var ankleSpan: CGFloat?
    var height: CGFloat          // shoulder-to-ankle, the scale reference
}

struct Frame {
    let t: Double
    var people: [Person]
}

func pt(_ o: VNHumanBodyPoseObservation, _ j: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
    guard let p = try? o.recognizedPoint(j), p.confidence >= jointFloor else { return nil }
    return CGPoint(x: p.location.x, y: p.location.y)
}

let asset = AVURLAsset(url: url)
guard let track = asset.tracks(withMediaType: .video).first else { print("no video track"); exit(1) }
let nominal = Double(track.nominalFrameRate)
let stride = max(1, Int((nominal / targetFPS).rounded()))

// A phone clip does not store its rotation in the pixels. It stores it in
// preferredTransform, and a portrait recording arrives as a landscape buffer
// with a 90-degree turn attached. Handing Vision the raw buffer is asking it
// to find a sideways human. On the ground-level two-player clip that one
// omission was the difference between 17 usable frames out of 100 and 86.
let xf = track.preferredTransform
let orientation: CGImagePropertyOrientation
switch (xf.a.rounded(), xf.b.rounded(), xf.c.rounded(), xf.d.rounded()) {
case (0, 1, -1, 0):   orientation = .right
case (0, -1, 1, 0):   orientation = .left
case (-1, 0, 0, -1):  orientation = .down
default:              orientation = .up
}

// Vision normalises x against the frame's width and y against its height, so
// on a 9:16 frame a step of 0.1 sideways is barely half the distance of 0.1
// upward. Every metric here is quoted in body heights, and a body height is
// measured in y — so x is converted into y-units once, at the point each
// joint is recorded, and the rest of the file can use plain distances.
let displaySize = track.naturalSize.applying(xf)
let aspect = abs(displaySize.width) / abs(displaySize.height)

let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(output)
reader.startReading()

var frames: [Frame] = []
var index = 0
while let sample = output.copyNextSampleBuffer() {
    defer { index += 1 }
    guard index % stride == 0, let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
    let t = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
    let request = VNDetectHumanBodyPoseRequest()
    try? VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation, options: [:])
        .perform([request])
    guard let obs = request.results, !obs.isEmpty else { continue }

    var people: [Person] = []
    for o in obs {
        guard let hipL = pt(o, .leftHip), let hipR = pt(o, .rightHip) else { continue }
        let hip = CGPoint(x: (hipL.x + hipR.x) / 2 * aspect, y: (hipL.y + hipR.y) / 2)
        let sL = pt(o, .leftShoulder), sR = pt(o, .rightShoulder)
        let aL = pt(o, .leftAnkle), aR = pt(o, .rightAnkle)
        let wrist = [pt(o, .rightWrist), pt(o, .leftWrist)].compactMap { $0 }.max { $0.y < $1.y }
        // Scale reference. Ankles are the least reliable joints at court
        // distance — gating on shoulder-to-ankle threw away 90% of the frames
        // in the first calibration run. The torso (shoulder to hip) survives
        // almost every frame, so scale from that and fall back to the ankle
        // only when it is actually there. Torso ≈ 0.30 of standing height, so
        // the ratio converts it to a comparable "body height".
        guard let shoulder = sL ?? sR else { continue }
        var height: CGFloat = 0
        if let ankle = aL ?? aR { height = abs(shoulder.y - ankle.y) }
        if height <= 0.08 { height = abs(shoulder.y - hip.y) / 0.30 }
        guard height > 0.05 else { continue }
        var span: CGFloat? = nil
        if let l = aL, let r = aR { span = abs(l.x - r.x) * aspect }
        people.append(Person(hip: hip, wrist: wrist, shoulderL: sL, shoulderR: sR,
                             ankleSpan: span, height: height))
    }
    if !people.isEmpty { frames.append(Frame(t: t, people: people)) }
}

guard !frames.isEmpty else { print("no pose found in any frame"); exit(1) }

// ── how many people are actually in this clip ────────────────────────────

let counts = frames.map(\.people.count)
let median = counts.sorted()[counts.count / 2]
let twoPlus = Double(counts.filter { $0 >= 2 }.count) / Double(counts.count)

print("frames with a person: \(frames.count) @ ~\(String(format: "%.0f", targetFPS)) fps")
print("people per frame — median \(median), max \(counts.max() ?? 0), "
      + "two-or-more in \(String(format: "%.0f%%", twoPlus * 100)) of frames")

// ── track two people across frames by nearest hip ────────────────────────
// Two players on a court sit at different depths, so hip position is a stable
// enough handle. This is the part that genuinely needs a real two-player clip
// to trust; on a one-player clip it simply reports one track.

struct Track { var id: Int; var last: CGPoint; var samples: [(t: Double, p: Person)] }
var tracks: [Track] = []
for frame in frames {
    var unused = frame.people
    for i in tracks.indices {
        guard !unused.isEmpty else { break }
        let (bestIdx, bestD) = unused.enumerated()
            .map { ($0.offset, hypot($0.element.hip.x - tracks[i].last.x,
                                     $0.element.hip.y - tracks[i].last.y)) }
            .min { $0.1 < $1.1 }!
        if bestD < 0.25 {
            tracks[i].last = unused[bestIdx].hip
            tracks[i].samples.append((frame.t, unused[bestIdx]))
            unused.remove(at: bestIdx)
        }
    }
    for p in unused where tracks.count < 4 {
        tracks.append(Track(id: tracks.count, last: p.hip, samples: [(frame.t, p)]))
    }
}
tracks.sort { $0.samples.count > $1.samples.count }
let players = Array(tracks.prefix(2))

print("\ntracks kept: \(players.count)")

// ── per-player measurements ──────────────────────────────────────────────
// Every one of these is a measurement, not an opinion, and each is stated in
// units the player can argue with.

func measure(_ t: Track) -> [String: Double] {
    let s = t.samples
    guard s.count > 4 else { return [:] }

    // ONE scale per player, not one per frame. A person's height does not
    // change during a clip, but the per-frame estimate is noisy, and dividing
    // every metric by a jittering denominator is what kept inflating these
    // numbers. The median is robust to the frames where a joint slipped.
    let heights = s.map(\.p.height).sorted()
    let meanHeight = heights[heights.count / 2]

    // Court coverage. Summing raw per-frame deltas accumulates pose jitter
    // into a number that keeps growing with clip length — the first run
    // reported 47 body-heights for 17 seconds. Smooth over five samples, then
    // only count a step that exceeds the jitter floor.
    var hips: [CGPoint] = []
    for i in s.indices {
        let lo = max(0, i - 2), hi = min(s.count - 1, i + 2)
        let win = s[lo...hi].map(\.p.hip)
        hips.append(CGPoint(x: win.map(\.x).reduce(0,+) / CGFloat(win.count),
                            y: win.map(\.y).reduce(0,+) / CGFloat(win.count)))
    }
    let jitterFloor = meanHeight * 0.05
    var travel: CGFloat = 0
    for i in 1..<hips.count {
        let d = hypot(hips[i].x - hips[i-1].x, hips[i].y - hips[i-1].y)
        if d > jitterFloor && d < meanHeight { travel += d }
    }
    let coverage = Double(travel / meanHeight)
    // Width of court actually used, which length cannot inflate.
    let lateralRange = Double(((hips.map(\.x).max() ?? 0) - (hips.map(\.x).min() ?? 0)) / meanHeight)

    // Base width at its widest — a real split-step / loaded stance shows a
    // stance wider than the shoulders.
    let spans = s.compactMap(\.p.ankleSpan).map { Double($0 / meanHeight) }
    let widestBase = spans.max() ?? 0

    // Readiness: how much of the clip is spent with a stance wider than half
    // the body height — standing still upright reads as low.
    let ready = Double(spans.filter { $0 > 0.22 }.count) / Double(max(spans.count, 1))

    // Highest wrist reached, body-height normalised: finish height and
    // overhead reach both show up here.
    var highestWrist = 0.0
    for e in s {
        guard let w = e.p.wrist, let sh = e.p.shoulderL ?? e.p.shoulderR else { continue }
        highestWrist = max(highestWrist, Double((w.y - sh.y) / max(e.p.height, 0.01)))
    }

    return ["coverage": coverage, "lateral_range": lateralRange,
            "widest_base": widestBase, "ready_share": ready,
            "wrist_peak": highestWrist, "frames": Double(s.count)]
}

for (i, t) in players.enumerated() {
    let m = measure(t)
    guard !m.isEmpty else { continue }
    let label = i == 0 ? "Player A" : "Player B"
    print("\n\(label)  (\(Int(m["frames"] ?? 0)) tracked frames)")
    print(String(format: "  width of court used   %.2f body-heights", m["lateral_range"] ?? 0))
    print(String(format: "  widest base           %.2f body-heights", m["widest_base"] ?? 0))
    print(String(format: "  time in a wide stance %.0f%%", (m["ready_share"] ?? 0) * 100))
    print(String(format: "  highest wrist         %+.2f body-heights above the shoulder", m["wrist_peak"] ?? 0))
    // Printed apart from the four above, because it is not the same kind of
    // number: it moved 166% between 12 fps and 6 fps on the same clip.
    print(String(format: "  [not reproducible] court coverage %.2f body-heights of travel",
                 m["coverage"] ?? 0))
}

if players.count < 2 {
    print("\nOnly one player tracked — this clip cannot produce a head-to-head.")
    print("The two-person association above is the piece that still needs a real")
    print("two-player clip before anyone should trust a verdict from it.")
}
