import Foundation
import AVFoundation
import UIKit

/// A single saved swing analysis: the AI report, an optional 0–100 score, and
/// the on-device file names for the saved video clip and its thumbnail. The
/// video and thumbnail bytes live in `Documents/Swings/`; only the file names
/// are persisted in the Codable record.
struct SwingAnalysisRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let strokeRaw: String
    let handednessRaw: String?
    let score: Int?
    let analysisText: String
    let videoFileName: String
    let thumbnailFileName: String

    /// Reconstructs the typed stroke from the stored rawValue (nil if unknown).
    var stroke: SwingStroke? { SwingStroke(rawValue: strokeRaw) }
    /// Reconstructs the typed handedness from the stored rawValue.
    var handedness: SwingHandedness? {
        guard let handednessRaw else { return nil }
        return SwingHandedness(rawValue: handednessRaw)
    }
}

/// Owns the user's saved swing analyses. Mirrors the storage pattern used by
/// `MatchEntryManager` (a Codable array in UserDefaults under a "CourtIQ.*.v1"
/// key) and additionally persists the source video + a thumbnail on disk under
/// `Documents/Swings/` so reports are fully browsable offline later.
@MainActor
final class SwingAnalysisStore: ObservableObject {
    static let shared = SwingAnalysisStore()

    @Published private(set) var records: [SwingAnalysisRecord] = []

    private let defaultsKey = "CourtIQ.swingAnalyses.v1"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.records = Self.load(from: userDefaults, key: defaultsKey)
    }

    // MARK: - Storage location

    /// `Documents/Swings/`, created on first use. Falls back to the temporary
    /// directory if the documents directory is somehow unavailable.
    private static var swingsDirectory: URL {
        let base = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Swings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// On-device URL for the saved video of `record`.
    func videoURL(for record: SwingAnalysisRecord) -> URL {
        Self.swingsDirectory.appendingPathComponent(record.videoFileName)
    }

    /// Loads and decodes the saved thumbnail for `record`, if present.
    func thumbnailImage(for record: SwingAnalysisRecord) -> UIImage? {
        let url = Self.swingsDirectory.appendingPathComponent(record.thumbnailFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - CRUD

    /// Copies `videoURL` into `Documents/Swings/<uuid>.mov`, renders a mid-clip
    /// JPEG thumbnail, and prepends a new record carrying the score. The clip is
    /// stored ON DEVICE (it is never deleted by this call). Failures to copy the
    /// video are tolerated — the record is still saved so the report isn't lost.
    func add(
        analysis: String,
        score: Int?,
        stroke: SwingStroke,
        handedness: SwingHandedness?,
        videoURL: URL
    ) async {
        let id = UUID()
        let videoFileName = "\(id.uuidString).mov"
        let thumbnailFileName = "\(id.uuidString).jpg"
        let dir = Self.swingsDirectory

        // Copy the source clip on device.
        let destVideoURL = dir.appendingPathComponent(videoFileName)
        try? FileManager.default.removeItem(at: destVideoURL)
        try? FileManager.default.copyItem(at: videoURL, to: destVideoURL)

        // Render a mid-clip thumbnail (longest side ~400px, JPEG ~0.7).
        if let thumbData = await Self.makeThumbnailData(from: videoURL) {
            let destThumbURL = dir.appendingPathComponent(thumbnailFileName)
            try? thumbData.write(to: destThumbURL, options: .atomic)
        }

        let record = SwingAnalysisRecord(
            id: id,
            date: Date(),
            strokeRaw: stroke.rawValue,
            handednessRaw: handedness?.rawValue,
            score: score,
            analysisText: analysis,
            videoFileName: videoFileName,
            thumbnailFileName: thumbnailFileName
        )
        records.insert(record, at: 0)
        records.sort { $0.date > $1.date }
        persist()
    }

    /// Removes a record and its on-device video + thumbnail files.
    func delete(_ record: SwingAnalysisRecord) {
        let dir = Self.swingsDirectory
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(record.videoFileName))
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(record.thumbnailFileName))
        records.removeAll { $0.id == record.id }
        persist()
    }

    // MARK: - Thumbnail

    /// Pulls a mid-clip frame, downscales it to a ~400px longest side, and
    /// JPEG-encodes it at quality 0.7. Returns nil if the frame can't be read.
    private static func makeThumbnailData(from videoURL: URL) async -> Data? {
        let asset = AVURLAsset(url: videoURL)
        guard let durationSeconds = try? await CMTimeGetSeconds(asset.load(.duration)),
              durationSeconds.isFinite, durationSeconds > 0 else {
            return nil
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        let midpoint = CMTime(seconds: durationSeconds * 0.5, preferredTimescale: 600)
        guard let cgImage = try? await copyImage(generator: generator, at: midpoint) else {
            return nil
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.7)
    }

    private static func copyImage(generator: AVAssetImageGenerator, at time: CMTime) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if result == .succeeded, let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: CocoaError(.fileReadCorruptFile))
                }
            }
        }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        userDefaults.set(data, forKey: defaultsKey)
    }

    private static func load(from defaults: UserDefaults, key: String) -> [SwingAnalysisRecord] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SwingAnalysisRecord].self, from: data)
        else {
            return []
        }
        return decoded.sorted { $0.date > $1.date }
    }
}
