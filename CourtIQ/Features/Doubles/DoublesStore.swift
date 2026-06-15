import Foundation
import Combine

/// Owns the user's saved doubles partners + their compatibility reports.
/// Mirrors the storage pattern used by `MatchEntryManager` / `SwingAnalysisStore`
/// (Codable arrays in UserDefaults under "CourtIQ.*.v1" keys). `@MainActor`
/// singleton so views can `@StateObject private var store = DoublesStore.shared`.
@MainActor
final class DoublesStore: ObservableObject {
    static let shared = DoublesStore()

    @Published private(set) var partners: [DoublesPartner] = []
    @Published private(set) var reports: [DoublesReport] = []

    private let partnersKey = "CourtIQ.doublesPartners.v1"
    private let reportsKey = "CourtIQ.doublesReports.v1"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.partners = Self.load([DoublesPartner].self, from: userDefaults, key: partnersKey) ?? []
        self.reports = Self.load([DoublesReport].self, from: userDefaults, key: reportsKey) ?? []
    }

    // MARK: - Partner CRUD

    /// Insert a new partner or update an existing one (matched by `id`).
    func save(_ partner: DoublesPartner) {
        if let index = partners.firstIndex(where: { $0.id == partner.id }) {
            partners[index] = partner
        } else {
            partners.append(partner)
        }
        persistPartners()
    }

    /// Remove a partner and ALL of its saved reports.
    func deletePartner(_ id: UUID) {
        partners.removeAll { $0.id == id }
        reports.removeAll { $0.partnerId == id }
        persistPartners()
        persistReports()
    }

    func partner(withID id: UUID) -> DoublesPartner? {
        partners.first { $0.id == id }
    }

    // MARK: - Reports

    func addReport(_ report: DoublesReport) {
        reports.append(report)
        persistReports()
    }

    /// Reports for a partner, newest-first.
    func reports(forPartner id: UUID) -> [DoublesReport] {
        reports
            .filter { $0.partnerId == id }
            .sorted { $0.date > $1.date }
    }

    /// The most recent compatibility score for a partner, if any report carries
    /// one. Used by the list row badge.
    func latestScore(forPartner id: UUID) -> Int? {
        reports(forPartner: id).first(where: { $0.score != nil })?.score
    }

    /// Wipe everything. Used by the session-reset flow.
    func resetLocalData() {
        partners = []
        reports = []
        userDefaults.removeObject(forKey: partnersKey)
        userDefaults.removeObject(forKey: reportsKey)
    }

    // MARK: - Persistence

    private func persistPartners() {
        guard let data = try? JSONEncoder().encode(partners) else { return }
        userDefaults.set(data, forKey: partnersKey)
    }

    private func persistReports() {
        guard let data = try? JSONEncoder().encode(reports) else { return }
        userDefaults.set(data, forKey: reportsKey)
    }

    private static func load<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
