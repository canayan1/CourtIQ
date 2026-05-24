import Foundation

/// Owns the user's local AI Coach state — thread list, in-thread
/// messages, daily quota mirror — and brokers calls to the
/// `ai-chat` Supabase Edge Function via `SupabaseRESTClient`.
///
/// Persistence: UserDefaults + JSONEncoder (same shape as
/// MatchEntryManager / DailyQuizManager). Cross-device sync is
/// handled by Supabase Postgres; the local cache is just for
/// instant UI on app launch.
@MainActor
final class AIChatClient: ObservableObject {

    // MARK: - Published state

    @Published private(set) var threads: [AIChatThread] = []
    /// Mirror of the server's `messagesRemainingToday` after the most
    /// recent successful call. `nil` until the first call lands.
    @Published private(set) var remainingToday: Int?
    @Published var lastError: String?

    // MARK: - Dependencies

    static let shared = AIChatClient()

    private let userDefaults: UserDefaults
    private let client: SupabaseRESTClient
    private let storeKey = "CourtIQ.AIChat.threads.v1"
    private let remainingKey = "CourtIQ.AIChat.remainingToday.v1"
    private let remainingDateKey = "CourtIQ.AIChat.remainingDate.v1"

    init(
        userDefaults: UserDefaults = .standard,
        client: SupabaseRESTClient = .shared
    ) {
        self.userDefaults = userDefaults
        self.client = client
        loadFromDisk()
    }

    // MARK: - Public API

    /// Send a user message to the AI Coach and append the reply to the
    /// given thread (or start a new thread when `threadID` is nil).
    /// `contextProvider` is a closure so callers can lazily assemble
    /// the latest match/quiz/profile context only when actually about
    /// to send — keeps the call site simple and avoids stale snapshots.
    func send(
        message: String,
        threadID: String?,
        session: SupabaseSession,
        contextProvider: () -> AIChatContextPayload?
    ) async throws -> AIChatThread {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RemoteDataError.message("Empty message.")
        }

        // Optimistic local insert so the chat UI feels instant.
        let activeID = threadID ?? UUID().uuidString
        let pendingUser = AIChatMessage(
            chatID: activeID,
            role: .user,
            content: trimmed,
            pending: false
        )
        let pendingAssistant = AIChatMessage(
            chatID: activeID,
            role: .assistant,
            content: "",
            pending: true
        )
        upsertLocal(threadID: activeID, fallbackTitle: trimmed, appending: [pendingUser, pendingAssistant])

        // Hit the Edge Function.
        let response: AIChatResponsePayload
        do {
            response = try await client.invokeAIChat(
                request: AIChatRequestPayload(
                    message: trimmed,
                    chatId: threadID,
                    context: contextProvider()
                ),
                session: session
            )
        } catch {
            // Roll back the pending assistant row and surface the error.
            removePending(threadID: activeID, messageID: pendingAssistant.id)
            lastError = humanReadable(error)
            throw error
        }

        // Replace the pending assistant placeholder with the real reply.
        // Use the chatId returned by the server — Supabase generates the
        // UUID on its side when threadID was nil.
        let serverThreadID = response.chatId
        replaceAssistant(
            optimisticThreadID: activeID,
            serverThreadID: serverThreadID,
            assistantMessageID: pendingAssistant.id,
            replyContent: response.reply,
            fallbackTitle: trimmed
        )

        rememberQuota(remaining: response.messagesRemainingToday)
        persistToDisk()

        guard let thread = threads.first(where: { $0.id == serverThreadID }) else {
            throw RemoteDataError.invalidResponse
        }
        return thread
    }

    /// Erase a thread locally. The server-side row stays for now —
    /// could add an `invokeAIChatDeleteThread` later if needed.
    func deleteThreadLocally(id: String) {
        threads.removeAll { $0.id == id }
        persistToDisk()
    }

    // MARK: - Local mutation helpers

    private func upsertLocal(
        threadID: String,
        fallbackTitle: String,
        appending: [AIChatMessage]
    ) {
        if let idx = threads.firstIndex(where: { $0.id == threadID }) {
            threads[idx].messages.append(contentsOf: appending)
            threads[idx].lastMessageAt = Date()
        } else {
            let new = AIChatThread(
                id: threadID,
                title: deriveTitle(from: fallbackTitle),
                lastMessageAt: Date(),
                messages: appending
            )
            threads.insert(new, at: 0)
        }
    }

    private func removePending(threadID: String, messageID: String) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[idx].messages.removeAll { $0.id == messageID }
    }

    private func replaceAssistant(
        optimisticThreadID: String,
        serverThreadID: String,
        assistantMessageID: String,
        replyContent: String,
        fallbackTitle: String
    ) {
        // If the server returned a different thread ID than the one we
        // optimistically used (i.e. this was a fresh chat), reindex the
        // thread locally so subsequent sends carry the canonical id.
        if optimisticThreadID != serverThreadID,
           let idx = threads.firstIndex(where: { $0.id == optimisticThreadID }) {
            var moved = threads.remove(at: idx)
            moved = AIChatThread(
                id: serverThreadID,
                title: moved.title,
                lastMessageAt: moved.lastMessageAt,
                messages: moved.messages.map { m in
                    var copy = m
                    return AIChatMessage(
                        id: copy.id,
                        chatID: serverThreadID,
                        role: copy.role,
                        content: copy.content,
                        createdAt: copy.createdAt,
                        pending: copy.pending
                    )
                }
            )
            threads.insert(moved, at: 0)
        }

        guard let idx = threads.firstIndex(where: { $0.id == serverThreadID }) else {
            // Defensive: still upsert a fresh thread so the reply lands somewhere.
            threads.insert(AIChatThread(
                id: serverThreadID,
                title: deriveTitle(from: fallbackTitle),
                lastMessageAt: Date(),
                messages: [AIChatMessage(
                    id: assistantMessageID, chatID: serverThreadID,
                    role: .assistant, content: replyContent
                )]
            ), at: 0)
            return
        }

        if let mIdx = threads[idx].messages.firstIndex(where: { $0.id == assistantMessageID }) {
            threads[idx].messages[mIdx].content = replyContent
            threads[idx].messages[mIdx].pending = false
        } else {
            threads[idx].messages.append(AIChatMessage(
                chatID: serverThreadID, role: .assistant, content: replyContent
            ))
        }
        threads[idx].lastMessageAt = Date()
    }

    private func deriveTitle(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New chat" : String(trimmed.prefix(60))
    }

    // MARK: - Quota mirror

    private func rememberQuota(remaining: Int) {
        remainingToday = remaining
        userDefaults.set(remaining, forKey: remainingKey)
        userDefaults.set(Date().timeIntervalSince1970, forKey: remainingDateKey)
    }

    /// If our cached "remainingToday" is from yesterday, treat it as nil
    /// so the UI doesn't tell the user they're out of messages on a
    /// fresh day. Server is source of truth on the next real call.
    func refreshQuotaForToday() {
        let ts = userDefaults.double(forKey: remainingDateKey)
        guard ts > 0 else { remainingToday = nil; return }
        let stored = Date(timeIntervalSince1970: ts)
        if !Calendar.current.isDateInToday(stored) {
            remainingToday = nil
            userDefaults.removeObject(forKey: remainingKey)
            userDefaults.removeObject(forKey: remainingDateKey)
        } else {
            remainingToday = userDefaults.object(forKey: remainingKey) as? Int
        }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        if let data = userDefaults.data(forKey: storeKey),
           let decoded = try? JSONDecoder().decode([AIChatThread].self, from: data) {
            threads = decoded.sorted { $0.lastMessageAt > $1.lastMessageAt }
        }
        refreshQuotaForToday()
    }

    private func persistToDisk() {
        guard let data = try? JSONEncoder().encode(threads) else { return }
        userDefaults.set(data, forKey: storeKey)
    }

    private func humanReadable(_ error: Error) -> String {
        if let e = error as? RemoteDataError {
            return e.localizedDescription
        }
        return error.localizedDescription
    }
}
