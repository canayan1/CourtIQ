import AVFoundation
import UIKit

/// Pulls evenly-spaced still frames out of a swing clip, downscales and
/// JPEG-encodes each, and returns them base64-encoded (NO `data:` prefix) so
/// they can be dropped straight into the edge-function request body.
enum SwingFrameExtractor {

    enum ExtractionError: LocalizedError {
        case unreadableVideo
        case notEnoughFrames
        case tooLong

        var errorDescription: String? {
            switch self {
            case .unreadableVideo:  return "The video could not be read."
            case .notEnoughFrames:  return "Not enough frames could be extracted from the video."
            case .tooLong:          return "Please use a clip under 20 seconds — a single swing is plenty."
            }
        }
    }

    /// Hard cap on clip length. A single swing fits easily; longer clips spread
    /// the sampled frames too thin and waste analysis on dead time.
    static let maxDurationSeconds: Double = 21

    /// Target number of frames sampled across the clip. The edge function
    /// accepts 2–10; 8 gives the model a good motion sequence without bloating
    /// the request.
    private static let targetFrameCount = 8
    /// Longest side, in pixels, of each downscaled frame.
    private static let maxDimension: CGFloat = 768
    /// JPEG compression quality.
    private static let jpegQuality: CGFloat = 0.7

    /// Extracts ~`targetFrameCount` frames evenly spaced across the clip.
    /// Returns at least 2 base64 JPEG strings, or throws.
    static func extractFrames(from videoURL: URL) async throws -> [String] {
        let asset = AVURLAsset(url: videoURL)

        let duration = try await loadDurationSeconds(for: asset)
        guard duration > 0 else { throw ExtractionError.unreadableVideo }
        guard duration <= maxDurationSeconds else { throw ExtractionError.tooLong }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)

        // Sample inside the clip (skip the very first/last instants which are
        // often blurry or black) at evenly-spaced fractions of the duration.
        let times = sampleTimes(duration: duration, count: targetFrameCount)

        var frames: [String] = []
        for time in times {
            do {
                let cgImage = try await copyImage(generator: generator, at: time)
                if let encoded = encode(cgImage) {
                    frames.append(encoded)
                }
            } catch {
                // A single failed sample shouldn't sink the whole run — keep
                // collecting and decide at the end whether we have enough.
                continue
            }
        }

        guard frames.count >= 2 else { throw ExtractionError.notEnoughFrames }
        return frames
    }

    // MARK: - Helpers

    private static func sampleTimes(duration: Double, count: Int) -> [CMTime] {
        guard count > 0 else { return [] }
        // Spread samples across [0.05, 0.95] of the duration so we avoid the
        // dead frames at the very start and end.
        let start = 0.05, end = 0.95
        let span = end - start
        return (0..<count).map { i in
            let fraction = count == 1 ? 0.5 : start + span * (Double(i) / Double(count - 1))
            return CMTime(seconds: duration * fraction, preferredTimescale: 600)
        }
    }

    private static func loadDurationSeconds(for asset: AVURLAsset) async throws -> Double {
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    private static func copyImage(generator: AVAssetImageGenerator, at time: CMTime) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if result == .succeeded, let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ExtractionError.unreadableVideo)
                }
            }
        }
    }

    /// Downscale (belt-and-suspenders on top of `maximumSize`), JPEG-encode at
    /// `jpegQuality`, and base64 the bytes (no `data:` prefix).
    private static func encode(_ cgImage: CGImage) -> String? {
        let image = UIImage(cgImage: cgImage)
        let resized = downscale(image, longestSide: maxDimension)
        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return nil }
        return data.base64EncodedString()
    }

    private static func downscale(_ image: UIImage, longestSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > longestSide, longest > 0 else { return image }

        let scale = longestSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
