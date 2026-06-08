import Foundation
import Combine

/// Owns saved doubles partnerships. Mirrors the app's manager pattern
/// (`@MainActor` singleton, UserDefaults + Codable JSON — same as
/// `CourtTapDrillManager` / `DailyQuizManager`). Local-only for v1.1;
/// account sync arrives in a later step.
@MainActor
final class DoublesStore: ObservableObject {
    static let shared = DoublesStore()

    @Published private(set) var partnerships: [DoublesPartnership] = []

    private let defaults: UserDefaults
    // v2: DoublesProfile gained chemistry fields (temperament/goal) and
    // dropped poach/pressure — old v1 blobs won't decode, so use a new key.
    private let key = "CourtIQ.doubles.partnerships.v2"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.partnerships = Self.load(from: defaults, key: key)
    }

    /// Insert or update a partnership (newest first).
    func save(_ p: DoublesPartnership) {
        partnerships.removeAll { $0.id == p.id }
        partnerships.insert(p, at: 0)
        persist()
    }

    func delete(_ p: DoublesPartnership) {
        partnerships.removeAll { $0.id == p.id }
        persist()
    }

    func resetLocalData() {
        partnerships = []
        defaults.removeObject(forKey: key)
    }

    // MARK: - Persistence
    private func persist() {
        if let data = try? JSONEncoder().encode(partnerships) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load(from defaults: UserDefaults, key: String) -> [DoublesPartnership] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DoublesPartnership].self, from: data)
        else { return [] }
        return decoded
    }
}
