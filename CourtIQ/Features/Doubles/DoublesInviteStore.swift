import Foundation
import Combine

/// Caches the user's `doubles_partnerships` rows + the compatibility report
/// computed for each one. Mirrors `DoublesStore`'s storage pattern (Codable in
/// UserDefaults under "CourtIQ.*.v1" keys, `@MainActor` singleton).
///
/// Reports are keyed by partnership id so each pairing keeps its own report.
@MainActor
final class DoublesInviteStore: ObservableObject {
    static let shared = DoublesInviteStore()

    @Published private(set) var partnerships: [DoublesPartnership] = []
    /// Compatibility report per partnership id.
    @Published private(set) var reportsByPartnership: [UUID: DoublesReport] = [:]

    private let partnershipsKey = "CourtIQ.doublesPartnerships.v1"
    private let reportsKey = "CourtIQ.doublesPartnershipReports.v1"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.partnerships = Self.load([DoublesPartnership].self, from: userDefaults, key: partnershipsKey) ?? []
        self.reportsByPartnership = Self.load([UUID: DoublesReport].self, from: userDefaults, key: reportsKey) ?? [:]
    }

    // MARK: - Partnerships

    /// Replace the cached set with the freshly-fetched rows (server is source
    /// of truth). Prunes reports whose partnership no longer exists.
    func replacePartnerships(_ rows: [DoublesPartnership]) {
        partnerships = rows
        let liveIds = Set(rows.map { $0.id })
        reportsByPartnership = reportsByPartnership.filter { liveIds.contains($0.key) }
        persistPartnerships()
        persistReports()
    }

    /// Insert/update one partnership in the cache (e.g. right after createInvite).
    func upsert(_ partnership: DoublesPartnership) {
        if let index = partnerships.firstIndex(where: { $0.id == partnership.id }) {
            partnerships[index] = partnership
        } else {
            partnerships.insert(partnership, at: 0)
        }
        persistPartnerships()
    }

    var activePartnerships: [DoublesPartnership] {
        partnerships.filter { $0.isActive }
    }

    var pendingPartnerships: [DoublesPartnership] {
        partnerships.filter { !$0.isActive }
    }

    // MARK: - Reports

    func report(forPartnership id: UUID) -> DoublesReport? {
        reportsByPartnership[id]
    }

    func score(forPartnership id: UUID) -> Int? {
        reportsByPartnership[id]?.score
    }

    func setReport(_ report: DoublesReport, forPartnership id: UUID) {
        reportsByPartnership[id] = report
        persistReports()
    }

    // MARK: - Reset

    func resetLocalData() {
        partnerships = []
        reportsByPartnership = [:]
        userDefaults.removeObject(forKey: partnershipsKey)
        userDefaults.removeObject(forKey: reportsKey)
    }

    // MARK: - Persistence

    private func persistPartnerships() {
        guard let data = try? JSONEncoder().encode(partnerships) else { return }
        userDefaults.set(data, forKey: partnershipsKey)
    }

    private func persistReports() {
        guard let data = try? JSONEncoder().encode(reportsByPartnership) else { return }
        userDefaults.set(data, forKey: reportsKey)
    }

    private static func load<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
