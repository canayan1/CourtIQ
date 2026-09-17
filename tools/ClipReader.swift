import AVFoundation
import CoreImage
import CoreGraphics
import Foundation

/// Reads a clip into grey frames, a background and a motion count.
///
/// Shared by the duel tools so that a fix lands in both. It holds every
/// sampled frame in memory, which is fine for a desktop calibration run on a
/// few hundred frames and is NOT how the app should do it — on device the
/// background wants a running estimate rather than a stack.
struct Clip {
    let width: Int
    let height: Int
    let times: [Double]
    let frames: [[Float]]
    let background: [Float]
    /// How many frames each pixel differed from the background — the clip's
    /// own record of where anything happened.
    let motionCount: [Int]

    func motionMask(_ index: Int, threshold: Float = 22) -> [Bool] {
        let f = frames[index]
        var mask = [Bool](repeating: false, count: width * height)
        for i in 0..<(width * height) where abs(f[i] - background[i]) > threshold { mask[i] = true }
        return mask
    }

    static func read(url: URL, fps: Double = 5) throws -> Clip {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw NSError(domain: "Clip", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "no video track"])
        }
        // Rotation lives in preferredTransform, never in the pixels. Ignoring
        // it is how an earlier calibration run spent its time analysing
        // sideways people.
        let xf = track.preferredTransform
        let display = track.naturalSize.applying(xf)
        let W = Int(abs(display.width).rounded()), H = Int(abs(display.height).rounded())
        let rotation: CGFloat
        switch (xf.a.rounded(), xf.b.rounded(), xf.c.rounded(), xf.d.rounded()) {
        case (0, 1, -1, 0):  rotation = -.pi / 2
        case (0, -1, 1, 0):  rotation = .pi / 2
        case (-1, 0, 0, -1): rotation = .pi
        default:             rotation = 0
        }

        let step = max(1, Int((Double(track.nominalFrameRate) / fps).rounded()))
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(output)
        reader.startReading()

        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        let space = CGColorSpaceCreateDeviceRGB()
        var frames: [[Float]] = [], times: [Double] = []
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
                                      bytesPerRow: W * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { continue }
            bmp.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
            var grey = [Float](repeating: 0, count: W * H)
            for i in 0..<(W * H) {
                grey[i] = 0.299 * Float(bytes[i * 4]) + 0.587 * Float(bytes[i * 4 + 1])
                        + 0.114 * Float(bytes[i * 4 + 2])
            }
            frames.append(grey)
            times.append(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample)))
        }
        guard frames.count >= 8 else {
            throw NSError(domain: "Clip", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "only \(frames.count) usable frames — too short"])
        }

        // Median over the clip is the court with the players taken out.
        var background = [Float](repeating: 0, count: W * H)
        var column = [Float](repeating: 0, count: frames.count)
        for i in 0..<(W * H) {
            for (j, f) in frames.enumerated() { column[j] = f[i] }
            column.sort()
            background[i] = column[column.count / 2]
        }
        var motion = [Int](repeating: 0, count: W * H)
        for f in frames {
            for i in 0..<(W * H) where abs(f[i] - background[i]) > 22 { motion[i] += 1 }
        }
        return Clip(width: W, height: H, times: times, frames: frames,
                    background: background, motionCount: motion)
    }
}

/// Saves a greyscale buffer with coloured overlays — the only way to check a
/// geometric claim is to draw it back on the picture it came from.
struct Overlay {
    let ctx: CGContext
    let height: Int

    init?(background: [Float], width: Int, height: Int) {
        guard let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        for y in 0..<height {
            for x in 0..<width {
                let v = CGFloat(background[y * width + x] / 255)
                c.setFillColor(red: v, green: v, blue: v, alpha: 1)
                c.fill(CGRect(x: x, y: height - 1 - y, width: 1, height: 1))
            }
        }
        ctx = c
        self.height = height
    }

    func line(_ a: CGPoint, _ b: CGPoint, _ rgb: (CGFloat, CGFloat, CGFloat), width: CGFloat = 2) {
        ctx.setStrokeColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        ctx.setLineWidth(width)
        ctx.move(to: CGPoint(x: a.x, y: CGFloat(height) - a.y))
        ctx.addLine(to: CGPoint(x: b.x, y: CGFloat(height) - b.y))
        ctx.strokePath()
    }

    func dot(_ p: CGPoint, _ rgb: (CGFloat, CGFloat, CGFloat), r: CGFloat = 3) {
        ctx.setFillColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: CGFloat(height) - p.y - r, width: r * 2, height: r * 2))
    }

    func write(to url: URL) {
        guard let img = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
    }
}
