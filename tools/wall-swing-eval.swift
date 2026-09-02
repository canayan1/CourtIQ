#!/usr/bin/env swift
// Offline check for the wall swing detector — runs Vision body pose over a
// phone video on the Mac and prints every swing it would have fired, with the
// forehand/backhand call, so thresholds can be tuned against a real session
// BEFORE a build goes near a user.
//
//   swift tools/wall-swing-eval.swift ~/Desktop/wall.mov [right|left]
//
// Read it against what actually happened on the wall: total swings, and the
// FH/BH sequence. If the count is off, the numbers to move are at the top of
// CourtIQ/Features/Wall/WallSwingDetector.swift — this script mirrors them.
//
// Runs on macOS 14+. Shoot the clip the way the app asks: phone behind the
// player, a step to the side, whole body in frame.

import AVFoundation
import Vision
import CoreGraphics

// ── mirror of WallSwingDetector's tuning ─────────────────────────────────
let swingSpeed: CGFloat = 2.2
let rearmShare: CGFloat = 0.40
let refractory: Double = 0.55
let sideMargin: CGFloat = 0.035
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
let t = track.preferredTransform
let orientation: CGImagePropertyOrientation = {
    if t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0 { return .right }
    if t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0 { return .left }
    if t.a == -1.0 && t.d == -1.0 { return .down }
    return .up
}()

let request = VNDetectHumanBodyPoseRequest()
var lastT = -1.0, lastWrist = CGPoint.zero, haveLast = false
var speedSmoothed: CGFloat = 0, armed = true, lastSwingAt = -10.0
var swings: [(Double, String, Float)] = []
var frames = 0, posed = 0

while let sb = output.copyNextSampleBuffer() {
    frames += 1
    guard let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
    let time = CMSampleBufferGetPresentationTimeStamp(sb).seconds
    let handler = VNImageRequestHandler(cvPixelBuffer: pb, orientation: orientation)
    try? handler.perform([request])
    guard let obs = request.results?.first,
          let pts = try? obs.recognizedPoints(.all) else { haveLast = false; continue }
    posed += 1
    let wristName: VNHumanBodyPoseObservation.JointName = rightHanded ? .rightWrist : .leftWrist
    guard let w = pts[wristName], w.confidence >= jointFloor else { haveLast = false; continue }
    let midX: CGFloat? = {
        if let l = pts[.leftShoulder], let r = pts[.rightShoulder],
           l.confidence >= jointFloor, r.confidence >= jointFloor { return (l.location.x + r.location.x) / 2 }
        if let l = pts[.leftHip], let r = pts[.rightHip],
           l.confidence >= jointFloor, r.confidence >= jointFloor { return (l.location.x + r.location.x) / 2 }
        if let n = pts[.neck], n.confidence >= jointFloor { return n.location.x }
        return nil
    }()
    let wrist = CGPoint(x: w.location.x, y: 1 - w.location.y)
    defer { lastT = time; lastWrist = wrist; haveLast = true }
    guard haveLast else { continue }
    let dt = time - lastT
    guard dt > 0.005, dt < 0.25 else { continue }
    let speed = hypot(wrist.x - lastWrist.x, wrist.y - lastWrist.y) / CGFloat(dt)
    speedSmoothed = speedSmoothed * 0.45 + speed * 0.55
    if !armed { if speedSmoothed < swingSpeed * rearmShare { armed = true }; continue }
    guard speedSmoothed >= swingSpeed, time - lastSwingAt >= refractory else { continue }
    armed = false; lastSwingAt = time
    var stroke = "?"; var conf: Float = 0
    if let mid = midX {
        let off = wrist.x - mid
        let fhSide = rightHanded ? off > 0 : off < 0
        if abs(off) >= sideMargin {
            stroke = fhSide ? "FH" : "BH"
            conf = min(1, Float(abs(off) / (sideMargin * 3))) * w.confidence
        }
    }
    swings.append((time, stroke, conf))
}

print("frames \(frames) · pose found in \(posed) · swings \(swings.count)")
for (t, s, c) in swings { print(String(format: "  %6.2fs  %-2@  conf %.2f", t, s as NSString, c)) }
let seq = swings.map { $0.1 }.joined(separator: " ")
print("sequence: \(seq)")
