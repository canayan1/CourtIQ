import Foundation

/// A saved doubles partnership. Stores only the two questionnaire profiles
/// (+ name/date); the `DoublesResult` is derived on demand from the pure
/// scorer, so there's a single source of truth and no stale cached score.
/// `aiPlan` caches the optional premium output (wired in Step 6).
struct DoublesPartnership: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var partnerName: String
    var createdAt: Date
    var myProfile: DoublesProfile
    var partnerProfile: DoublesProfile
    var aiPlan: String?

    init(id: UUID = UUID(),
         partnerName: String,
         createdAt: Date = Date(),
         myProfile: DoublesProfile,
         partnerProfile: DoublesProfile,
         aiPlan: String? = nil) {
        self.id = id
        self.partnerName = partnerName
        self.createdAt = createdAt
        self.myProfile = myProfile
        self.partnerProfile = partnerProfile
        self.aiPlan = aiPlan
    }

    /// Derived, deterministic compatibility result.
    var result: DoublesResult {
        DoublesCompatibility.score(myProfile, partnerProfile)
    }
}
