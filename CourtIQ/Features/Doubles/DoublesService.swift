import Foundation
import Combine

/// Server-backed doubles partnerships (account-linked invite flow + joint
/// match log). Talks to Supabase via the existing `SupabaseRESTClient`
/// CRUD/RPC helpers. RLS scopes every read/write to the signed-in user, so
/// a partnership is visible to exactly its two participants.
///
/// Session: injected as a provider (set once at app start) that returns a
/// usable `SupabaseSession` — mints an anonymous one if the user hasn't
/// connected Apple yet (same approach as the AI Coach), giving a real
/// `auth.uid()` for RLS without a sign-in wall.

// MARK: - Wire DTOs (camelCase <-> snake_case handled by the client coder)

struct DoublesPartnershipRow: Codable, Identifiable, Equatable {
    let id: UUID
    let code: String
    let inviterUserId: String
    let inviterName: String?
    let inviterProfile: DoublesProfile
    let inviteeUserId: String?
    let inviteeName: String?
    let inviteeProfile: DoublesProfile?
    let status: String
    let createdAt: Date?
    let acceptedAt: Date?

    var isActive: Bool { inviteeProfile != nil }

    /// Compatibility result once both halves are in.
    var result: DoublesResult? {
        guard let inviteeProfile else { return nil }
        return DoublesCompatibility.score(inviterProfile, inviteeProfile)
    }

    /// True if the signed-in user is the inviter (vs the invitee). Used to
    /// orient the result ("You" = this device's player).
    func viewerIsInviter(_ userID: String) -> Bool { inviterUserId == userID }

    /// Orient this row for the signed-in viewer so the shared result view
    /// renders "you" (this device) vs "partner" correctly. Nil until both
    /// halves are in.
    func viewerPartnership(userID: String) -> DoublesPartnership? {
        guard let inviteeProfile else { return nil }
        let iAmInviter = viewerIsInviter(userID)
        let mine = iAmInviter ? inviterProfile : inviteeProfile
        let theirs = iAmInviter ? inviteeProfile : inviterProfile
        let rawName = iAmInviter ? inviteeName : inviterName
        let theirName = (rawName?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? "Partner"
        return DoublesPartnership(id: id, partnerName: theirName,
                                  createdAt: createdAt ?? Date(),
                                  myProfile: mine, partnerProfile: theirs)
    }
}

struct DoublesInvitePeek: Decodable {
    let inviterName: String?
    let status: String?
    let alreadyMember: Bool?
}

struct DoublesMatchRow: Codable, Identifiable, Equatable {
    let id: UUID
    let partnershipId: UUID
    let loggedByUserId: String?
    let playedOn: String          // yyyy-MM-dd (date column; kept as String)
    let won: Bool?
    let score: String?
    let opponents: String?
    let notes: String?
    let createdAt: Date?
}

// MARK: - Service

@MainActor
final class DoublesService: ObservableObject {
    static let shared = DoublesService()

    @Published private(set) var partnerships: [DoublesPartnershipRow] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    /// The signed-in user's id (anonymous or Apple). Used to orient a
    /// partnership row's result as "you" vs "partner".
    @Published private(set) var currentUserID: String?

    private let client = SupabaseRESTClient.shared
    private var sessionProvider: (() async throws -> SupabaseSession)?

    private static let table = "doubles_partnerships"
    private static let matchTable = "doubles_matches"

    /// Set once at app start, e.g.
    /// `DoublesService.shared.configure { try await userSession.ensureAnonymousSession() }`
    func configure(sessionProvider: @escaping () async throws -> SupabaseSession) {
        self.sessionProvider = sessionProvider
    }

    private func session() async throws -> SupabaseSession {
        guard let sessionProvider else { throw RemoteDataError.missingConfiguration }
        let s = try await sessionProvider()
        if currentUserID != s.userID { currentUserID = s.userID }
        return s
    }

    var isConfigured: Bool { client.isConfigured && sessionProvider != nil }

    // MARK: Partnerships

    func loadPartnerships() async {
        guard isConfigured else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let session = try await session()
            let rows: [DoublesPartnershipRow] = try await client.selectRows(
                from: Self.table,
                queryItems: [URLQueryItem(name: "order", value: "created_at.desc")],
                session: session
            )
            partnerships = rows
            lastError = nil
        } catch {
            lastError = (error as? RemoteDataError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Inviter creates a pending partnership with their half; returns the row
    /// (its `code` goes into the share link).
    @discardableResult
    func createInvite(myName: String?, myProfile: DoublesProfile) async throws -> DoublesPartnershipRow {
        let session = try await session()
        struct NewInvite: Encodable {
            let code: String
            let inviterUserId: String
            let inviterName: String?
            let inviterProfile: DoublesProfile
        }
        let payload = NewInvite(
            code: Self.makeCode(),
            inviterUserId: session.userID,
            inviterName: doublesBlankToNil(myName),
            inviterProfile: myProfile
        )
        let row: DoublesPartnershipRow = try await client.insertRow(payload, into: Self.table, session: session)
        await loadPartnerships()
        return row
    }

    /// Pre-accept peek: who invited me + status (the invitee isn't a row
    /// participant yet, so this goes through the SECURITY DEFINER RPC).
    func peekInvite(code: String) async throws -> DoublesInvitePeek {
        let session = try await session()
        struct Args: Encodable { let inviteCode: String }
        let rows: [DoublesInvitePeek] = try await client.callRPC(
            "peek_doubles_invite", args: Args(inviteCode: code), session: session
        )
        guard let first = rows.first else { throw RemoteDataError.message("Invite not found.") }
        return first
    }

    /// Invitee accepts: fills their half via RPC, then fetches the now-shared
    /// partnership (both halves → score).
    @discardableResult
    func acceptInvite(code: String, myName: String?, myProfile: DoublesProfile) async throws -> DoublesPartnershipRow {
        let session = try await session()
        struct Args: Encodable {
            let inviteCode: String
            let pInviteeName: String?
            let pInviteeProfile: DoublesProfile
        }
        let _: UUID = try await client.callRPC(
            "accept_doubles_invite",
            args: Args(inviteCode: code, pInviteeName: doublesBlankToNil(myName), pInviteeProfile: myProfile),
            session: session
        )
        // Now a participant → fetch the full row.
        let rows: [DoublesPartnershipRow] = try await client.selectRows(
            from: Self.table,
            queryItems: [URLQueryItem(name: "code", value: "eq.\(code)")],
            session: session
        )
        await loadPartnerships()
        guard let row = rows.first else { throw RemoteDataError.invalidResponse }
        return row
    }

    func deletePartnership(_ row: DoublesPartnershipRow) async {
        do {
            let session = try await session()
            try await client.deleteRows(
                from: Self.table,
                queryItems: [URLQueryItem(name: "id", value: "eq.\(row.id.uuidString.lowercased())")],
                session: session
            )
            partnerships.removeAll { $0.id == row.id }
        } catch {
            lastError = (error as? RemoteDataError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: Matches (joint doubles match log)

    func loadMatches(partnershipID: UUID) async -> [DoublesMatchRow] {
        do {
            let session = try await session()
            return try await client.selectRows(
                from: Self.matchTable,
                queryItems: [
                    URLQueryItem(name: "partnership_id", value: "eq.\(partnershipID.uuidString.lowercased())"),
                    URLQueryItem(name: "order", value: "played_on.desc")
                ],
                session: session
            )
        } catch {
            lastError = (error as? RemoteDataError)?.errorDescription ?? error.localizedDescription
            return []
        }
    }

    @discardableResult
    func logMatch(partnershipID: UUID, playedOn: String, won: Bool?, score: String?,
                  opponents: String?, notes: String?) async throws -> DoublesMatchRow {
        let session = try await session()
        struct NewMatch: Encodable {
            let partnershipId: UUID
            let loggedByUserId: String
            let playedOn: String
            let won: Bool?
            let score: String?
            let opponents: String?
            let notes: String?
        }
        let payload = NewMatch(
            partnershipId: partnershipID,
            loggedByUserId: session.userID,
            playedOn: playedOn,
            won: won,
            score: doublesBlankToNil(score),
            opponents: doublesBlankToNil(opponents),
            notes: doublesBlankToNil(notes)
        )
        return try await client.insertRow(payload, into: Self.matchTable, session: session)
    }

    // MARK: Helpers

    /// Short, unambiguous share code (no 0/O/1/I/L to avoid copy errors).
    private static func makeCode(length: Int = 8) -> String {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<length).map { _ in alphabet.randomElement()! })
    }
}

/// Trim a String? to nil when blank (local helper; the app's
/// `nilIfEmptyTrimmed` is fileprivate to another file).
private func doublesBlankToNil(_ s: String?) -> String? {
    guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
    return t
}
