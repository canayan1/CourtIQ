// The swing lab, offline: one side-on clip of a player hitting from a feed,
// and a ten-rep picture of the stroke — where contact happened relative to
// the body, how high, how high the finish, and how consistent all of that
// was across reps.
//
//   swiftc -O tools/swing-lab.swift CourtIQ/Features/SwingAnalysis/BallImpactAudio.swift -o /tmp/lab
//   /tmp/lab <clip> [out.txt]
//
// Step 2 of docs/TEACHING-PLAN.md. What it measures is VARIABILITY and
// CHANGE, never correctness: a stroke that is the same ten times is a learned
// stroke whatever it looks like. It refuses a clip that is not the lab setup
// — fewer than five reps with a readable body is not a lab session, and the
// tool says so rather than measuring something else.
//
// Contact is the audio impact (the calibrated detector), and the body is
// Vision pose at that instant with the clip's rotation applied — the two
// lessons from the duel work.

import AVFoundation
import Foundation
import Vision

let argv = CommandLine.arguments
guard argv.count >= 2 else { print("usage: swing-lab <clip> [out.txt]"); exit(1) }
let url = URL(fileURLWithPath: argv[1])
let asset = AVURLAsset(url: url)
guard let track = asset.tracks(withMediaType: .video).first else { print("no video"); exit(1) }
let display = track.naturalSize.applying(track.preferredTransform)
let W = abs(display.width), H = abs(display.height)
let aspect = W / H          // x is normalised to width, y to height — same units before measuring

guard asset.tracks(withMediaType: .audio).first != nil else {
    print("NOT A LAB SESSION: this clip has no audio track, and contact is found by sound.")
    print("Record with the microphone on — the app's own capture always does.")
    exit(2)
}
let sem = DispatchSemaphore(value: 0)
var impacts: [(t: Double, strength: Double)] = []
Task {
    guard let env = try? BallImpactAudio.readEnvelope(asset: asset) else { sem.signal(); return }
    impacts = BallImpactAudio.detectImpactsWithStrength(envelope: env, dt: BallImpactAudio.envelopeWindow,
                                                        minGap: BallImpactAudio.wallMinGap)
    sem.signal()
}
sem.wait()
print("\(impacts.count) contacts heard in \(String(format: "%.0f", CMTimeGetSeconds(asset.duration))) s")

let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
gen.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)

struct Body { var hip: CGPoint; var shoulder: CGPoint; var wrist: CGPoint; var height: Double
              /// Apparent shoulder span over body height. Side-on, the two
              /// shoulders nearly line up and this is small; square to the
              /// camera it is about 0.25. It is how the tool knows the clip
              /// was shot from the side, which the numbers assume.
              var shoulderSpan: Double }
func body(at t: Double) -> Body? {
    guard let cg = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) else { return nil }
    let req = VNDetectHumanBodyPoseRequest()
    try? VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:]).perform([req])
    guard let o = req.results?.first else { return nil }
    func p(_ j: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        guard let r = try? o.recognizedPoint(j), r.confidence > 0.3 else { return nil }
        return CGPoint(x: r.location.x * aspect, y: r.location.y)
    }
    guard let hl = p(.leftHip), let hr = p(.rightHip), let sl = p(.leftShoulder) ?? p(.rightShoulder) else { return nil }
    let span: Double
    if let a = p(.leftShoulder), let b = p(.rightShoulder) { span = abs(Double(a.x - b.x)) } else { span = 0 }
    let hip = CGPoint(x: (hl.x + hr.x) / 2, y: (hl.y + hr.y) / 2)
    // the racket arm is the wrist further from the hip line at contact
    let wrists = [p(.leftWrist), p(.rightWrist)].compactMap { $0 }
    guard let wrist = wrists.max(by: { abs($0.x - hip.x) < abs($1.x - hip.x) }) else { return nil }
    var height = 0.0
    if let a = p(.leftAnkle) ?? p(.rightAnkle) { height = abs(Double(sl.y - a.y)) }
    if height < 0.08 { height = abs(Double(sl.y - hip.y)) / 0.30 }
    guard height > 0.05 else { return nil }
    return Body(hip: hip, shoulder: sl, wrist: wrist, height: height, shoulderSpan: span / height)
}

struct Rep { var t: Double; var ahead: Double; var contactHeight: Double; var finishHeight: Double? }
var reps: [Rep] = []
var heights: [Double] = [], spans: [Double] = []
for hit in impacts {
    guard let b = body(at: hit.t) else { continue }
    heights.append(b.height); spans.append(b.shoulderSpan)
    let ahead = Double(b.wrist.x - b.hip.x) / b.height
    let ch = Double(b.wrist.y - b.hip.y) / b.height
    var fin: Double? = nil
    if let f = body(at: hit.t + 0.35) { fin = Double(f.wrist.y - f.shoulder.y) / f.height }
    reps.append(Rep(t: hit.t, ahead: ahead, contactHeight: ch, finishHeight: fin))
}
print("\(reps.count) reps with a readable body at contact")
// The setup gate. Everything below assumes a body that fills the frame,
// seen from the side. From behind a baseline at twenty metres the body is a
// tenth of the frame and the shoulders sit square to the lens; the pose
// still comes back, and the numbers it produces are noise wearing the same
// units. The first version measured exactly such a clip and reported a
// tempo spread of 1.27 s as if it meant something.
if !heights.isEmpty {
    let hs = heights.sorted(), ss = spans.sorted()
    let h = hs[hs.count / 2], sp = ss[ss.count / 2]
    print(String(format: "body height %.0f%% of frame, shoulder span %.2f of height", h * 100, sp))
    if h < 0.25 {
        print("\nNOT A LAB SESSION: the player is too small in the frame (\(Int(h * 100))% of its height;")
        print("the lab wants at least 25%). Three metres, side-on, still camera.")
        exit(2)
    }
    if sp > 0.18 {
        print("\nNOT A LAB SESSION: the player is facing the camera, not side-on to it.")
        print("The lab measures the swing from the side; from the front there is no swing to see.")
        exit(2)
    }
}
guard reps.count >= 5 else {
    print("\nNOT A LAB SESSION: fewer than five reps could be measured. Side-on, three metres,")
    print("still camera, fed balls — anything else is refused rather than measured.")
    exit(2)
}

func stats(_ xs: [Double]) -> (median: Double, spread: Double) {
    let s = xs.sorted(); let m = s[s.count / 2]
    let q1 = s[s.count / 4], q3 = s[min(s.count - 1, s.count * 3 / 4)]
    return (m, q3 - q1)
}
// `ahead` is signed by which way the player faces; report its magnitude so
// a left-hander and a right-hander read the same way.
let ahead = stats(reps.map { abs($0.ahead) })
let ch = stats(reps.map(\.contactHeight))
let fins = reps.compactMap(\.finishHeight)
var lines: [String] = []
lines.append(String(format: "contact ahead of the hip    median %.2f body-heights   spread %.2f", ahead.median, ahead.spread))
lines.append(String(format: "contact height above hip    median %+.2f body-heights   spread %.2f", ch.median, ch.spread))
if fins.count >= 5 {
    let f = stats(fins)
    lines.append(String(format: "finish height above shoulder median %+.2f body-heights   spread %.2f", f.median, f.spread))
}
let gaps = zip(reps.dropFirst().map(\.t), reps.map(\.t)).map { $0 - $1 }.sorted()
if gaps.count >= 4 {
    let g = stats(gaps)
    lines.append(String(format: "tempo between reps          median %.2f s              spread %.2f s", g.median, g.spread))
}
print("\nTEN-REP PICTURE (\(reps.count) reps):")
for l in lines { print("  " + l) }
print("\n  Spread is the interquartile range across reps: small means the same")
print("  stroke every time. Nothing here says whether the stroke is correct.")
if argv.count >= 3 { try? (lines.joined(separator: "\n") + "\n").write(toFile: argv[2], atomically: true, encoding: .utf8) }
