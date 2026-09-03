#!/usr/bin/env swift
// Offline check for the wall swing detector — runs Vision body pose over a
// phone video on the Mac and prints every swing it would have fired, with the
// forehand/backhand call, so thresholds can be tuned against a real session
// BEFORE a build goes near a user.
//
//   swift tools/wall-swing-eval.swift ~/Downloads/wall.mov [right|left]
//
// Read it against what actually happened on the wall: total swings, and the
// FH/BH sequence. The numbers at the top mirror
// CourtIQ/Features/Wall/WallSwingDetector.swift — keep them in step.
//
// Runs on macOS 14+. Shoot the clip the way the app asks: phone behind the
// player, a step to the side, whole body in frame.

import AVFoundation
import Vision
import CoreGraphics

// ── mirror of WallSwingDetector's tuning ─────────────────────────────────
let turnShare: CGFloat = 0.25
let squareShare: CGFloat = 0.60
let minTurn: Double = 0.15
let refractory: Double = 0.50
let neutralDecay: CGFloat = 0.995
let sideMargin: CGFloat = 0.03
let sideWindow: Double = 0.20
let jointFloor: Float = 0.3

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: swift tools/wall-swing-eval.swift <video> [right|left]"); exit(1)
}
let url = URL(fileURLWithPath: args[1])
let rightHanded = (args.count < 3) || args[2] != "left"

let asset = AVURLAsset(url: url)
guard let track = asset.tracks(withMediaType: .video).first else {
    print("no video track"); exit(1)
}
let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
])
reader.add(output)
reader.startReading()

// Phone footage carries its rotation as a transform; ask Vision to undo it.
let tf = track.preferredTransform
let orientation: CGImagePropertyOrientation = {
    if tf.a == 0 && tf.b == 1.0 && tf.c == -1.0 && tf.d == 0 { return .right }
    if tf.a == 0 && tf.b == -1.0 && tf.c == 1.0 && tf.d == 0 { return .left }
    if tf.a == -1.0 && tf.d == -1.0 { return .down }
    return .up
}()

let request = VNDetectHumanBodyPoseRequest()
var turnedSince: Double? = nil
var neutral: CGFloat = 0
var lastSwingAt = -10.0
var pending: (Double, Double)? = nil
var swings: [(Double, String, Float)] = []
var frames = 0, posed = 0, shouldered = 0

func side(_ p: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> (String, Float)? {
    guard let lh = p[.leftHip], let rh = p[.rightHip], lh.confidence >= jointFloor, rh.confidence >= jointFloor else { return nil }
    let mid = (lh.location.x + rh.location.x) / 2
    let arms: [VNHumanBodyPoseObservation.JointName] = [.rightElbow, .leftElbow, .rightWrist, .leftWrist]
    let seen = arms.compactMap { p[$0] }.filter { $0.confidence >= jointFloor }
    guard !seen.isEmpty else { return nil }
    let off = seen.map { $0.location.x - mid }.reduce(0, +) / CGFloat(seen.count)
    let trust = seen.map(\.confidence).reduce(0, +) / Float(seen.count)
    guard abs(off) >= sideMargin else { return ("?", 0) }
    let dominant = rightHanded ? off > 0 : off < 0
    return (dominant ? "FH" : "BH", min(1, Float(abs(off) / (sideMargin * 4))) * trust)
}

while let sb = output.copyNextSampleBuffer() {
    frames += 1
    guard let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
    let t = CMSampleBufferGetPresentationTimeStamp(sb).seconds
    let handler = VNImageRequestHandler(cvPixelBuffer: pb, orientation: orientation)
    try? handler.perform([request])
    let pts = (request.results?.first).flatMap { try? $0.recognizedPoints(.all) }
    if pts != nil { posed += 1 }
    if let p = pending {
        if let pts, let (s, c) = side(pts) { swings.append((p.0, s, c)); pending = nil }
        else if t >= p.1 { swings.append((p.0, "?", 0)); pending = nil }
    }
    guard let pts, let ls = pts[.leftShoulder], let rs = pts[.rightShoulder],
          ls.confidence >= jointFloor, rs.confidence >= jointFloor else { continue }
    shouldered += 1
    let width = rs.location.x - ls.location.x
    neutral = max(neutral * neutralDecay, abs(width))
    guard neutral >= 0.05 else { continue }
    if let since = turnedSince {
        guard width > neutral * squareShare else { continue }
        turnedSince = nil
        guard t - since >= minTurn, t - lastSwingAt >= refractory else { continue }
        lastSwingAt = t
        if let (s, c) = side(pts) { swings.append((t, s, c)) } else { pending = (t, t + sideWindow) }
    } else if width < neutral * turnShare {
        turnedSince = t
    }
}

print("frames \(frames) · pose \(posed) · both shoulders \(shouldered) · swings \(swings.count)")
for (t, s, c) in swings { print(String(format: "  %6.2fs  %-2@  conf %.2f", t, s as NSString, c)) }
print("sequence: \(swings.map { $0.1 }.joined(separator: " "))")
