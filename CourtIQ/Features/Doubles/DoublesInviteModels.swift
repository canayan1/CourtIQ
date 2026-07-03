import Foundation

/// The portable doubles mini-profile carried in the `inviter_profile` /
/// `invitee_profile` jsonb columns of `doubles_partnerships`. Mirrors the
/// analytical fields of `DoublesPartner` so a remote profile can be turned
/// straight back into a `DoublesPartner` and fed to `DoublesService.analyze`.
///
/// Encoded with explicit snake_case keys (NOT relying on a global key strategy)
/// so the jsonb payload is stable regardless of which encoder writes it.
struct DoublesProfile: Codable, Equatable {
    var name: String
    /// `TennisLevel.rawValue` (Int-backed) as a String, or nil.
    var levelRaw: String?
    /// `SwingHandedness.rawValue` ("right" | "left"), or nil.
    var handednessRaw: String?
    /// `TennisArchetype.rawValue` ("aggressiveBaseliner" …), or nil.
    var styleRaw: String?
    var strengths: String
    var weaknesses: String

    enum CodingKeys: String, CodingKey {
        case name
        case levelRaw = "level_raw"
        case handednessRaw = "handedness_raw"
        case styleRaw = "style_raw"
        case strengths
        case weaknesses
    }

    init(
        name: String,
        levelRaw: String? = nil,
        handednessRaw: String? = nil,
        styleRaw: String? = nil,
        strengths: String = "",
        weaknesses: String = ""
    ) {
        self.name = name
        self.levelRaw = levelRaw
        self.handednessRaw = handednessRaw
        self.styleRaw = styleRaw
        self.strengths = strengths
        self.weaknesses = weaknesses
    }

    /// Turn this remote profile into a `DoublesPartner` so it can drive the
    /// existing `DoublesService.analyze(partner:language:session:)`. The "You"
    /// side of that summary always comes from the local Tennis Profile, so the
    /// partner here is purely the OTHER player's mini-profile.
    func asPartner() -> DoublesPartner {
        DoublesPartner(
            name: name,
            levelRaw: levelRaw,
            handednessRaw: handednessRaw,
            styleRaw: styleRaw,
            strengths: strengths,
            weaknesses: weaknesses
        )
    }

    // MARK: Display helpers (pair profile cards)

    /// Localized level title ("Solid club player"…) from the raw
    /// `TennisLevel.rawValue` string, or nil when absent/unparseable.
    func levelTitle(lang: AppLanguage) -> String? {
        guard let raw = levelRaw, let value = Int(raw),
              let level = TennisLevel(rawValue: value) else { return nil }
        return TennisProfileCopy(lang: lang).levelTitle(level)
    }

    /// Localized style/archetype title ("Aggressive baseliner"…), or nil.
    func styleTitle(lang: AppLanguage) -> String? {
        guard let raw = styleRaw, let archetype = TennisArchetype(rawValue: raw) else { return nil }
        return TennisProfileCopy(lang: lang).archetypeTitle(archetype)
    }
}

/// Status of a partnership row.
enum PartnershipStatus: String, Codable {
    case pending
    case active
    /// Any value the server might add later decodes to `.pending` semantics for
    /// the UI (treated as "not yet active").
    case unknown

    init(from raw: String?) {
        switch raw?.lowercased() {
        case "active": self = .active
        case "pending": self = .pending
        default: self = .unknown
        }
    }
}

/// One row of the live `doubles_partnerships` table. Decoded with explicit
/// snake_case `CodingKeys` (the table-returning calls use a plain decoder, not
/// the REST client's convert-from-snake-case one).
struct DoublesPartnership: Codable, Identifiable, Equatable {
    let id: UUID
    let code: String
    let inviterUserId: String
    let inviterName: String?
    let inviterProfile: DoublesProfile?
    let inviteeUserId: String?
    let inviteeName: String?
    let inviteeProfile: DoublesProfile?
    let status: String
    let createdAt: Date?
    let acceptedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case inviterUserId = "inviter_user_id"
        case inviterName = "inviter_name"
        case inviterProfile = "inviter_profile"
        case inviteeUserId = "invitee_user_id"
        case inviteeName = "invitee_name"
        case inviteeProfile = "invitee_profile"
        case status
        case createdAt = "created_at"
        case acceptedAt = "accepted_at"
    }

    var statusValue: PartnershipStatus { PartnershipStatus(from: status) }

    var isActive: Bool { statusValue == .active }

    /// The OTHER side's profile relative to the current user. If I'm the
    /// inviter, the partner is the invitee (and vice versa).
    func partnerProfile(forCurrentUserId uid: String?) -> DoublesProfile? {
        guard let uid else {
            // No uid resolved — best-effort: prefer the invitee (the most
            // recently joined side) when present, else the inviter.
            return inviteeProfile ?? inviterProfile
        }
        if uid == inviterUserId { return inviteeProfile }
        if let inviteeUserId, uid == inviteeUserId { return inviterProfile }
        // Not obviously a participant; fall back to the invitee profile.
        return inviteeProfile ?? inviterProfile
    }

    /// The OTHER side's display name relative to the current user.
    func partnerDisplayName(forCurrentUserId uid: String?) -> String {
        let other: String?
        if let uid, uid == inviterUserId {
            other = inviteeName
        } else if let uid, let inviteeUserId, uid == inviteeUserId {
            other = inviterName
        } else {
            other = inviteeName ?? inviterName
        }
        let trimmed = other?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false ? trimmed : nil) ?? "Partner"
    }
}
