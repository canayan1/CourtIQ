import AVFoundation
import CoreImage
import CoreGraphics
import Foundation

/// Reads a clip in two passes so that memory does not grow with its length.
///
/// The first version held every sampled frame at once. That is fine for a
/// seventeen-second test and impossible for the three minutes of rallying the
/// measurement actually needs: at 10 fps that is 1800 frames, several
/// gigabytes before the analysis starts. So the background is estimated from a
/// sparse sample — a court does not change — and the tracking pass streams,
/// turning each frame into a mask and letting it go.
struct Clip {
    let width: Int
    let height: Int
    let duration: Double
    /// The court with the players taken out: the per-pixel median of a sparse
    /// sample of the clip.
    let background: [Float]
    /// How many of those sampled frames each pixel differed from the
    /// background — the clip's own record of where anything happened.
    let motionCount: [Int]
    let backgroundFrames: Int

    private let url: URL
    private let rotation: CGFloat

    /// 48 frames is plenty for a per-pixel median of a court that is not
    /// moving, and they are kept as bytes rather than floats: the motion
    /// threshold is 22 grey levels, so the extra precision of a float bought
    /// nothing and cost four times the memory. Together that is the difference
    /// between a gigabyte and a hundred megabytes on a 1080p clip, and between
    /// impossible and merely heavy at 4K.
    static func read(url: URL, backgroundFPS: Double = 2, maxFrames: Int = 48) throws -> Clip {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw NSError(domain: "Clip", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "no video track"])
        }
        // Rotation lives in preferredTransform, never in the pixels. Ignoring
        // it is how an earlier calibration run spent itself analysing sideways
        // people.
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
        let duration = CMTimeGetSeconds(asset.duration)

        // Spread the background sample over the WHOLE clip rather than taking
        // the first hundred frames: a median is only the empty court if the
        // players have moved away from where they started.
        let wanted = min(maxFrames, max(12, Int(duration * backgroundFPS)))
        var pool: [[UInt8]] = []
        try decode(url: url, W: W, H: H, rotation: rotation,
                   every: max(1, Int((duration * Double(track.nominalFrameRate)
                                      / Double(wanted)).rounded()))) { _, grey in
            pool.append(grey.map { UInt8(max(0, min(255, $0))) })
            return pool.count < maxFrames
        }
        guard pool.count >= 8 else {
            throw NSError(domain: "Clip", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "only \(pool.count) usable frames — too short"])
        }

        var background = [Float](repeating: 0, count: W * H)
        var column = [UInt8](repeating: 0, count: pool.count)
        for i in 0..<(W * H) {
            for (j, f) in pool.enumerated() { column[j] = f[i] }
            column.sort()
            background[i] = Float(column[column.count / 2])
        }
        var motion = [Int](repeating: 0, count: W * H)
        for f in pool {
            for i in 0..<(W * H) where abs(Float(f[i]) - background[i]) > 22 { motion[i] += 1 }
        }
        return Clip(width: W, height: H, duration: duration, background: background,
                    motionCount: motion, backgroundFrames: pool.count,
                    url: url, rotation: rotation)
    }

    /// Streams the clip again, handing out one motion mask at a time.
    func forEachMask(fps: Double, threshold: Float = 22,
                     _ body: (Double, [Bool]) -> Void) throws {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        let step = max(1, Int((Double(track.nominalFrameRate) / fps).rounded()))
        var mask = [Bool](repeating: false, count: width * height)
        try Clip.decode(url: url, W: width, H: height, rotation: rotation, every: step) { t, grey in
            for i in 0..<(self.width * self.height) {
                mask[i] = abs(grey[i] - self.background[i]) > threshold
            }
            body(t, mask)
            return true
        }
    }

    /// Decodes every `every`-th frame to greyscale, upright. The callback
    /// returns false to stop early.
    private static func decode(url: URL, W: Int, H: Int, rotation: CGFloat, every: Int,
                               _ body: (Double, [Float]) -> Bool) throws {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(output)
        reader.startReading()

        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        let space = CGColorSpaceCreateDeviceRGB()
        var bytes = [UInt8](repeating: 0, count: W * H * 4)
        var grey = [Float](repeating: 0, count: W * H)
        var index = 0
        var keepGoing = true
        while keepGoing, let sample = output.copyNextSampleBuffer() {
            defer { index += 1 }
            guard index % every == 0, let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            // Each frame rents a CGImage and a bitmap from CoreImage. Without
            // a pool around the loop they are all still alive at the end of
            // it, which on a 1080p clip is most of the memory the tool uses.
            autoreleasepool {
            var image = CIImage(cvPixelBuffer: buffer)
            if rotation != 0 { image = image.transformed(by: CGAffineTransform(rotationAngle: rotation)) }
            image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX,
                                                            y: -image.extent.minY))
            guard let cg = ctx.createCGImage(image, from: CGRect(x: 0, y: 0, width: W, height: H))
            else { return }
            let ok: Bool = bytes.withUnsafeMutableBytes { raw -> Bool in
                guard let bmp = CGContext(data: raw.baseAddress, width: W, height: H,
                                          bitsPerComponent: 8, bytesPerRow: W * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                else { return true }
                bmp.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
                return true
            }
            guard ok else { keepGoing = false; return }
            for i in 0..<(W * H) {
                grey[i] = 0.299 * Float(bytes[i * 4]) + 0.587 * Float(bytes[i * 4 + 1])
                        + 0.114 * Float(bytes[i * 4 + 2])
            }
            if !body(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample)), grey) {
                keepGoing = false
            }
            }
        }
        if !keepGoing { reader.cancelReading() }
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
