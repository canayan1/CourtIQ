import Foundation
import Combine

/// Tracks which pro shot patterns the user has watched ("unlocked
/// to the library") and surfaces today's pick.
@MainActor
final class ProShotPatternsManager: ObservableObject {
    static let shared = ProShotPatternsManager()

    @Published private(set) var viewedIDs: Set<String>

    private let defaults: UserDefaults
    private let viewedKey = "CourtIQ.proShotViewed.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.array(forKey: viewedKey) as? [String] {
            self.viewedIDs = Set(raw)
        } else {
            self.viewedIDs = []
        }
    }

    var todaysPattern: ProShotPattern? {
        ProShotPattern.todaysPattern()
    }

    func markViewed(_ id: String) {
        guard !viewedIDs.contains(id) else { return }
        viewedIDs.insert(id)
        defaults.set(Array(viewedIDs), forKey: viewedKey)
    }

    func isViewed(_ id: String) -> Bool {
        viewedIDs.contains(id)
    }

    var viewedCount: Int { viewedIDs.count }
    var totalCount: Int { ProShotPattern.allPatterns.count }

    /// Patterns user has watched (for the library view).
    var library: [ProShotPattern] {
        ProShotPattern.allPatterns.filter { viewedIDs.contains($0.id) }
    }
}
