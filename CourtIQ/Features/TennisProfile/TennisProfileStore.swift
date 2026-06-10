import Foundation
import Combine

/// Owns the user's saved Tennis Profile. Mirrors the app's manager pattern
/// (`@MainActor` singleton, UserDefaults + Codable JSON). Single latest
/// profile — retaking replaces it.
@MainActor
final class TennisProfileStore: ObservableObject {
    static let shared = TennisProfileStore()

    @Published private(set) var profile: TennisProfile?

    private let defaults: UserDefaults
    private let key = "CourtIQ.tennisProfile.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.profile = Self.load(from: defaults, key: key)
    }

    var hasProfile: Bool { profile != nil }

    func save(_ p: TennisProfile) {
        profile = p
        persist()
    }

    /// Replace the adopted goals on the current profile (user edited their picks).
    func updateAdoptedGoals(_ goals: [TennisGoal]) {
        guard profile != nil else { return }
        profile?.adoptedGoals = goals
        persist()
    }

    func reset() {
        profile = nil
        defaults.removeObject(forKey: key)
    }

    private func persist() {
        if let p = profile, let data = try? JSONEncoder().encode(p) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load(from defaults: UserDefaults, key: String) -> TennisProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TennisProfile.self, from: data)
    }
}
