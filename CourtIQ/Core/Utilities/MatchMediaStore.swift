import Foundation

/// Owns the on-disk location of any media attached to a `MatchEntry` —
/// today voice notes, soon (v1.1.B) photos. Files live under the app's
/// Documents directory so they survive iCloud restores and the user can
/// see them in Files.app if they ever go looking.
///
/// All callers should round-trip through this store rather than touching
/// FileManager directly so that future changes to layout (e.g. moving
/// audio under iCloud Drive, or sharding by year) happen in one place.
enum MatchMediaStore {

    // MARK: - Public surface

    /// Returns the absolute URL on disk for a given bare file name.
    /// The file is NOT guaranteed to exist — callers should still
    /// check with `FileManager.default.fileExists(atPath:)`.
    static func audioURL(forFileName fileName: String) -> URL? {
        guard let dir = audioDirectoryURL() else { return nil }
        return dir.appendingPathComponent(fileName)
    }

    /// Allocates a fresh file name + URL pair for a new voice recording.
    /// Convention: `<scope>-<entryID>.m4a` where scope is "pre" or
    /// "post" — keeps two recordings per entry obvious in Files.app
    /// without leaking sensitive info into the file name.
    static func newAudioFile(scope: AudioScope, entryID: String) -> (fileName: String, url: URL)? {
        guard let dir = audioDirectoryURL() else { return nil }
        let name = "\(scope.rawValue)-\(entryID).m4a"
        ensureDirectoryExists(dir)
        return (name, dir.appendingPathComponent(name))
    }

    /// Best-effort cleanup of any audio attached to an entry. Called when
    /// the entry is deleted so we don't leak orphaned recordings. Silent
    /// no-op on missing files — deletion was the goal, missing == done.
    static func removeAudio(named fileNames: [String?]) {
        let fm = FileManager.default
        for case let name? in fileNames {
            guard let url = audioURL(forFileName: name) else { continue }
            try? fm.removeItem(at: url)
        }
    }

    // MARK: - Internals

    enum AudioScope: String {
        case pre
        case post
    }

    private static func audioDirectoryURL() -> URL? {
        guard let docs = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return docs.appendingPathComponent("MatchAudio", isDirectory: true)
    }

    private static func ensureDirectoryExists(_ url: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
