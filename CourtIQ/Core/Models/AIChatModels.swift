import Foundation

// MARK: - Wire types (match Edge Function contract)

/// Request body posted to the `ai-chat` Supabase Edge Function. Mirrors
/// the `ChatRequest` interface in `supabase/functions/ai-chat/index.ts`.
/// Keep the two in sync — bumping fields requires a function redeploy.
struct AIChatRequestPayload: Encodable {
    let message: String
    let chatId: String?
    let context: AIChatContextPayload?
}

/// Tennis context block. Client assembles this from local stores
/// (MatchEntryManager, DailyQuizManager, UserSession profile) before
/// every turn so the Edge Function never needs to know the iOS schema.
struct AIChatContextPayload: Encodable {
    let profile: ProfilePayload?
    let matches: [MatchPayload]?
    let quiz: QuizPayload?
    let tacticalProfile: TacticalProfilePayload?
    let playStyle: PlayStylePayload?
    let imported: String?

    enum CodingKeys: String, CodingKey {
        case profile
        case matches
        case quiz
        case tacticalProfile = "tactical_profile"
        case playStyle = "play_style"
        case imported
    }

    struct ProfilePayload: Encodable {
        let level: String?
        let focus: String?
        let topMistakePatterns: [String]?
        let currentFocus: String?
    }

    struct MatchPayload: Encodable {
        let date: String          // ISO 8601 short form (yyyy-MM-dd)
        let opponentName: String?
        let result: String        // "won" | "lost"
        let score: String?
        let surface: String?
        let ratings: RatingsPayload?
        let takeaway: String?
    }

    struct RatingsPayload: Encodable {
        let serve: Int?
        let `return`: Int?
        let movement: Int?
        let mental: Int?
    }

    struct QuizPayload: Encodable {
        let lastSessions: [QuizSessionPayload]?
        let topMistakes: [String]?
    }

    struct QuizSessionPayload: Encodable {
        let date: String
        let score: Int
        let total: Int
        let focusLabel: String?
    }

    /// Server-side coach reads this and can say things like "your
    /// Defensive Recovery is 1.8/5 across 12 reps — drill it".
    /// Only includes categories where the user has at least 3 taps
    /// so the AI doesn't anchor on a single noisy result.
    struct TacticalProfilePayload: Encodable {
        let openCourt: Double?
        let defense: Double?
        let approach: Double?
        let patterns: Double?
        let netGame: Double?
        let return_: Double?
        let totalDrillsCompleted: Int

        enum CodingKeys: String, CodingKey {
            case openCourt = "open_court"
            case defense
            case approach
            case patterns
            case netGame = "net_game"
            case return_ = "return"
            case totalDrillsCompleted = "total_drills_completed"
        }
    }

    /// Play-style fingerprint — feeds the AI Coach with the user's
    /// shot-type preferences and (when there's enough data) a coarse
    /// archetype label so it can say "you're a topspin baseliner".
    struct PlayStylePayload: Encodable {
        let topspinPct: Double?
        let flatPct: Double?
        let slicePct: Double?
        let dropPct: Double?
        let lobPct: Double?
        let shotTypeAccuracy: Double?
        let archetype: String?         // localised key — server treats as enum
        let totalShots: Int

        enum CodingKeys: String, CodingKey {
            case topspinPct        = "topspin_pct"
            case flatPct           = "flat_pct"
            case slicePct          = "slice_pct"
            case dropPct           = "drop_pct"
            case lobPct            = "lob_pct"
            case shotTypeAccuracy  = "shot_type_accuracy"
            case archetype
            case totalShots        = "total_shots"
        }
    }
}

/// Response from the Edge Function on a successful turn. Failures
/// surface as thrown `RemoteDataError` via the existing client error
/// translation so the UI alert path is shared with the rest of the app.
struct AIChatResponsePayload: Decodable {
    let reply: String
    let chatId: String
    let messagesRemainingToday: Int
    let usage: UsagePayload?
    let promptVersion: String?

    struct UsagePayload: Decodable {
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationInputTokens: Int?
        let cacheReadInputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
        }
    }
}

// MARK: - Local-store types (UI + persistence)

/// One turn rendered in the chat UI. Local mirror of `ai_messages`
/// rows, plus a transient `pending` flag for the optimistic-render
/// pattern (user message shows immediately, assistant streams in).
struct AIChatMessage: Identifiable, Codable, Hashable {
    let id: String
    let chatID: String
    let role: Role
    var content: String
    let createdAt: Date
    var pending: Bool

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    init(
        id: String = UUID().uuidString,
        chatID: String,
        role: Role,
        content: String,
        createdAt: Date = Date(),
        pending: Bool = false
    ) {
        self.id = id
        self.chatID = chatID
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.pending = pending
    }
}

/// A single AI Coach conversation thread. Stored locally — Supabase
/// is the source of truth across devices but the iOS app caches the
/// thread list + last message preview so the UI is instant.
struct AIChatThread: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var lastMessageAt: Date
    var messages: [AIChatMessage]

    init(id: String = UUID().uuidString,
         title: String = "New chat",
         lastMessageAt: Date = Date(),
         messages: [AIChatMessage] = []) {
        self.id = id
        self.title = title
        self.lastMessageAt = lastMessageAt
        self.messages = messages
    }
}
