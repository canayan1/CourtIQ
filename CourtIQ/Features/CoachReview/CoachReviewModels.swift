import Foundation

// MARK: - Order

enum CoachReviewStatus: String, Codable {
    case submitted, inReview = "in_review", delivered, refunded, cancelled

    /// Short, ≤3-word status a user reads at a glance.
    var shortLabelKey: String {
        switch self {
        case .submitted: return "coachreview.status_submitted"
        case .inReview:  return "coachreview.status_in_review"
        case .delivered: return "coachreview.status_delivered"
        case .refunded:  return "coachreview.status_refunded"
        case .cancelled: return "coachreview.status_cancelled"
        }
    }

    var isOpen: Bool { self == .submitted || self == .inReview }
}

/// A purchased human review. Mirrors `coach_review_orders`; the local copy is
/// the source of truth for the UI so the status card renders offline.
struct CoachReviewOrder: Codable, Identifiable, Hashable {
    let id: String
    var status: CoachReviewStatus
    var stroke: String
    var handedness: String?
    var note: String?
    var createdAt: Date
    var slaDueAt: Date
    var deliveredAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status, stroke, handedness, note
        case createdAt = "created_at"
        case slaDueAt = "sla_due_at"
        case deliveredAt = "delivered_at"
    }

    /// Hours left on the 72h SLA (nil once delivered).
    var hoursRemaining: Int? {
        guard status.isOpen else { return nil }
        let seconds = slaDueAt.timeIntervalSinceNow
        return seconds > 0 ? Int(seconds / 3600) : 0
    }
}

// MARK: - Deliverable ("One Thing" format — docs/COACH-REVIEW-TEMPLATE.md §6)

/// One checkpoint of the 5-point scorecard. `nil` means the coach could not
/// judge it from this angle — an honest gap, never a filled-in guess.
struct CoachReviewScorecard: Codable, Hashable {
    var preparation: Int?
    var contact: Int?
    var chain: Int?
    var finish: Int?
    var footwork: Int?

    /// Ordered rows for the UI: (localization key, score).
    var rows: [(key: String, score: Int?)] {
        [("coachreview.cp_preparation", preparation),
         ("coachreview.cp_contact", contact),
         ("coachreview.cp_chain", chain),
         ("coachreview.cp_finish", finish),
         ("coachreview.cp_footwork", footwork)]
    }
}

struct CoachReviewMicroNote: Codable, Hashable, Identifiable {
    var at: Double            // seconds into the clip
    var kind: String          // "good" | "fault"
    var text: String

    var id: String { "\(at)-\(text)" }
    var isGood: Bool { kind == "good" }

    /// `0:07` — timestamps are the proof the coach actually watched.
    var timestampLabel: String {
        let total = Int(at.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct CoachReviewDeliverable: Codable, Hashable {
    var orderID: String
    var scorecard: CoachReviewScorecard
    var oneThing: String
    var oneThingAt: Double?
    var oneThingCue: String?
    var microNotes: [CoachReviewMicroNote]
    var drillTitle: String?
    var drillBody: String?
    var voicePath: String?

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case scorecard
        case oneThing = "one_thing"
        case oneThingAt = "one_thing_at"
        case oneThingCue = "one_thing_cue"
        case microNotes = "micro_notes"
        case drillTitle = "drill_title"
        case drillBody = "drill_body"
        case voicePath = "voice_path"
    }
}
