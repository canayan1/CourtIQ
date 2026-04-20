import Foundation

enum DiscussionTargetType: String, CaseIterable, Codable, Identifiable {
    case quizItem
    case trainingSession
    case mobilityFlow
    case premiumInsight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quizItem: return "Quiz Item"
        case .trainingSession: return "Training Session"
        case .mobilityFlow: return "Mobility Flow"
        case .premiumInsight: return "Premium Insight"
        }
    }
}

struct ContentNodeID: Identifiable, Codable, Hashable {
    let targetType: DiscussionTargetType
    let targetID: String

    var id: String {
        "\(targetType.rawValue):\(targetID)"
    }
}

struct DiscussionThread: Identifiable, Codable, Hashable {
    let id: String
    let nodeID: ContentNodeID
    let title: String
    let subtitle: String
    let starterPrompt: String
    var lastUpdated: Date

    var lastActivityLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
}

struct DiscussionComment: Identifiable, Codable, Hashable {
    let id: String
    let threadID: String
    let authorID: String
    let authorName: String
    var body: String
    let createdAt: Date
    var likeCount: Int
    let isPinned: Bool
    var editedAt: Date?
    var viewerHasLiked: Bool
    var canEdit: Bool
    var canDelete: Bool
}

struct CommentReport: Identifiable, Codable, Hashable {
    let id: String
    let threadID: String
    let commentID: String
    let reason: String
    let createdAt: Date
}

@MainActor
final class DiscussionStore: ObservableObject {
    static let shared = DiscussionStore()

    @Published private(set) var threads: [DiscussionThread] = []
    @Published private(set) var commentsByThread: [String: [DiscussionComment]] = [:]
    @Published private(set) var reports: [CommentReport] = []

    private let defaults = UserDefaults.standard
    private let client = SupabaseRESTClient.shared
    private let threadsKey = "CourtIQ.Discussion.Threads"
    private let commentsKey = "CourtIQ.Discussion.Comments"
    private let reportsKey = "CourtIQ.Discussion.Reports"

    private init() {
        load()
        if threads.isEmpty {
            threads = Self.defaultThreads
            save()
        }
    }

    var featuredThreads: [DiscussionThread] {
        threads.sorted { lhs, rhs in
            let lhsCount = commentCount(for: lhs.id)
            let rhsCount = commentCount(for: rhs.id)
            if lhsCount == rhsCount {
                return lhs.lastUpdated > rhs.lastUpdated
            }
            return lhsCount > rhsCount
        }
    }

    func thread(withID id: String) -> DiscussionThread? {
        threads.first { $0.id == id }
    }

    func thread(for nodeID: ContentNodeID, title: String, subtitle: String, starterPrompt: String) -> DiscussionThread {
        if let existing = threads.first(where: { $0.nodeID == nodeID }) {
            return existing
        }

        let fallback = DiscussionThread(
            id: "thread-\(nodeID.targetType.rawValue)-\(nodeID.targetID)",
            nodeID: nodeID,
            title: title,
            subtitle: subtitle,
            starterPrompt: starterPrompt,
            lastUpdated: Date()
        )
        threads.append(fallback)
        save()

        Task {
            await ensureRemoteThreadIfPossible(fallback)
        }

        return fallback
    }

    func comments(for threadID: String) -> [DiscussionComment] {
        commentsByThread[threadID, default: []]
            .sorted { lhs, rhs in
                if lhs.isPinned == rhs.isPinned {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.isPinned && !rhs.isPinned
            }
    }

    func commentCount(for threadID: String) -> Int {
        commentsByThread[threadID, default: []].count
    }

    func syncAfterAuthentication() async throws {
        try await refreshFeaturedThreads()
    }

    func refreshFeaturedThreads() async throws {
        let remoteThreads: [RemoteDiscussionThreadRecord] = try await client.selectRows(
            from: "discussion_threads",
            queryItems: [URLQueryItem(name: "order", value: "updated_at.desc")],
            session: UserSessionManager.shared.remoteSession
        )

        if !remoteThreads.isEmpty {
            threads = remoteThreads.map(\.appModel)
            save()
        }

        for thread in threads.prefix(5) {
            try? await refreshThread(threadID: thread.id)
        }
    }

    func refreshThread(threadID: String) async throws {
        let session = UserSessionManager.shared.remoteSession
        let viewerID = UserSessionManager.shared.currentUserID

        let remoteComments: [RemoteDiscussionCommentRecord] = try await client.selectRows(
            from: "discussion_comments",
            queryItems: [
                URLQueryItem(name: "thread_id", value: "eq.\(threadID)"),
                URLQueryItem(name: "order", value: "created_at.asc")
            ],
            session: session
        )

        let likes: [RemoteCommentLikeRecord] = try await client.selectRows(
            from: "comment_likes",
            queryItems: [
                URLQueryItem(name: "thread_id", value: "eq.\(threadID)")
            ],
            session: session
        )

        let likeGroups = Dictionary(grouping: likes, by: \.commentID)
        commentsByThread[threadID] = remoteComments.map { comment in
            let commentLikes = likeGroups[comment.id, default: []]
            return DiscussionComment(
                id: comment.id,
                threadID: comment.threadID,
                authorID: comment.authorID,
                authorName: comment.authorName,
                body: comment.body,
                createdAt: comment.createdAt,
                likeCount: commentLikes.count,
                isPinned: comment.isPinned,
                editedAt: comment.editedAt,
                viewerHasLiked: commentLikes.contains(where: { $0.userID == viewerID }),
                canEdit: comment.authorID == viewerID,
                canDelete: comment.authorID == viewerID
            )
        }
        touch(threadID: threadID, to: remoteComments.map(\.createdAt).max() ?? thread(withID: threadID)?.lastUpdated ?? Date())
        save()
    }

    func postComment(body: String, to threadID: String) async throws {
        guard UserSessionManager.shared.canWriteCommunityComment,
              let session = UserSessionManager.shared.remoteSession else {
            throw RemoteDataError.message("Sign in with Apple and All Access are required to post.")
        }

        guard !ContentModerationFilter.containsBannedContent(body) else {
            throw RemoteDataError.message("Your comment contains content that isn't allowed. Please revise and try again.")
        }

        let comment = RemoteDiscussionCommentRecord(
            id: UUID().uuidString.lowercased(),
            threadID: threadID,
            authorID: session.userID,
            authorName: UserSessionManager.shared.displayName,
            body: body,
            isPinned: false,
            createdAt: Date(),
            editedAt: nil
        )

        _ = try await client.insertRow(comment, into: "discussion_comments", session: session) as RemoteDiscussionCommentRecord
        try await refreshThread(threadID: threadID)
    }

    func updateComment(commentID: String, in threadID: String, body: String) async throws {
        guard UserSessionManager.shared.canWriteCommunityComment,
              let session = UserSessionManager.shared.remoteSession else {
            throw RemoteDataError.message("Sign in with Apple and All Access are required to edit.")
        }

        guard !ContentModerationFilter.containsBannedContent(body) else {
            throw RemoteDataError.message("Your comment contains content that isn't allowed. Please revise and try again.")
        }

        _ = try await client.updateRows(
            RemoteCommentUpdatePayload(body: body, editedAt: Date()),
            in: "discussion_comments",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(commentID)"),
                URLQueryItem(name: "author_id", value: "eq.\(session.userID)")
            ],
            session: session
        ) as [RemoteDiscussionCommentRecord]

        try await refreshThread(threadID: threadID)
    }

    func toggleLike(commentID: String, in threadID: String) async throws {
        guard UserSessionManager.shared.canWriteCommunityComment,
              let session = UserSessionManager.shared.remoteSession else {
            throw RemoteDataError.message("Sign in with Apple and All Access are required to like comments.")
        }

        let viewerLikeID = "like-\(session.userID)-\(commentID)"
        let viewerHasLiked = comments(for: threadID).first(where: { $0.id == commentID })?.viewerHasLiked ?? false

        if viewerHasLiked {
            try await client.deleteRows(
                from: "comment_likes",
                queryItems: [
                    URLQueryItem(name: "id", value: "eq.\(viewerLikeID)")
                ],
                session: session
            )
        } else {
            let like = RemoteCommentLikeRecord(
                id: viewerLikeID,
                threadID: threadID,
                commentID: commentID,
                userID: session.userID,
                createdAt: Date()
            )
            _ = try await client.insertRow(like, into: "comment_likes", session: session) as RemoteCommentLikeRecord
        }

        try await refreshThread(threadID: threadID)
    }

    func deleteComment(commentID: String, in threadID: String) async throws {
        guard UserSessionManager.shared.canWriteCommunityComment,
              let session = UserSessionManager.shared.remoteSession else {
            throw RemoteDataError.message("Sign in with Apple and All Access are required to delete comments.")
        }

        try await client.deleteRows(
            from: "discussion_comments",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(commentID)"),
                URLQueryItem(name: "author_id", value: "eq.\(session.userID)")
            ],
            session: session
        )

        try await refreshThread(threadID: threadID)
    }

    func report(commentID: String, in threadID: String, reason: String) async throws {
        guard UserSessionManager.shared.canWriteCommunityComment,
              let session = UserSessionManager.shared.remoteSession else {
            throw RemoteDataError.message("Sign in with Apple and All Access are required to report comments.")
        }

        let report = RemoteCommentReportRecord(
            id: "report-\(session.userID)-\(commentID)",
            threadID: threadID,
            commentID: commentID,
            reporterID: session.userID,
            reason: reason,
            createdAt: Date()
        )

        let inserted: RemoteCommentReportRecord = try await client.insertRow(report, into: "comment_reports", session: session)
        reports.removeAll { $0.id == inserted.id }
        reports.append(inserted.appModel)
        save()
    }

    func reset() {
        resetLocalData()
    }

    func resetLocalData() {
        threads = Self.defaultThreads
        commentsByThread = [:]
        reports = []
        defaults.removeObject(forKey: threadsKey)
        defaults.removeObject(forKey: commentsKey)
        defaults.removeObject(forKey: reportsKey)
        save()
    }

    private func load() {
        if let threadData = defaults.data(forKey: threadsKey),
           let decodedThreads = try? JSONDecoder().decode([DiscussionThread].self, from: threadData) {
            threads = decodedThreads
        }

        if let commentData = defaults.data(forKey: commentsKey),
           let decodedComments = try? JSONDecoder().decode([String: [DiscussionComment]].self, from: commentData) {
            commentsByThread = decodedComments
        }

        if let reportData = defaults.data(forKey: reportsKey),
           let decodedReports = try? JSONDecoder().decode([CommentReport].self, from: reportData) {
            reports = decodedReports
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(threads) {
            defaults.set(data, forKey: threadsKey)
        }
        if let data = try? JSONEncoder().encode(commentsByThread) {
            defaults.set(data, forKey: commentsKey)
        }
        if let data = try? JSONEncoder().encode(reports) {
            defaults.set(data, forKey: reportsKey)
        }
    }

    private func touch(threadID: String, to date: Date = Date()) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[index].lastUpdated = date
    }

    private func ensureRemoteThreadIfPossible(_ thread: DiscussionThread) async {
        guard let session = UserSessionManager.shared.remoteSession else { return }

        do {
            let payload = RemoteDiscussionThreadRecord(thread: thread)
            _ = try await client.upsertRows([payload], into: "discussion_threads", onConflict: "id", session: session) as [RemoteDiscussionThreadRecord]
        } catch {
            await MainActor.run {
                UserSessionManager.shared.registerSyncError("Community threads could not refresh right now.")
            }
        }
    }

    private static let defaultThreads: [DiscussionThread] = [
        DiscussionThread(
            id: "thread-quiz-serve_001",
            nodeID: ContentNodeID(targetType: .quizItem, targetID: "serve_001"),
            title: "Second serve pressure choices",
            subtitle: "How players protect second serves without getting passive.",
            starterPrompt: "What is your safest second-serve pattern when the scoreboard gets tight?",
            lastUpdated: Date().addingTimeInterval(-7_200)
        ),
        DiscussionThread(
            id: "thread-training-hybrid-foundation",
            nodeID: ContentNodeID(targetType: .trainingSession, targetID: "training-hybrid-foundation"),
            title: "8-week hybrid foundation",
            subtitle: "How players manage soreness, cardio, and explosive work in one weekly plan.",
            starterPrompt: "Which day in the foundation week feels most transferable to your tennis goals right now?",
            lastUpdated: Date().addingTimeInterval(-18_000)
        ),
        DiscussionThread(
            id: "thread-mobility-quick-reset-001",
            nodeID: ContentNodeID(targetType: .mobilityFlow, targetID: "quick-reset-001"),
            title: "Serve Shoulder Reset",
            subtitle: "How the quick reset changes serve feel before practice or match play.",
            starterPrompt: "Do you use this flow before serving sessions, after, or both?",
            lastUpdated: Date().addingTimeInterval(-12_000)
        )
    ]
}

private struct RemoteDiscussionThreadRecord: Codable {
    let id: String
    let targetType: DiscussionTargetType
    let targetID: String
    let title: String
    let subtitle: String
    let starterPrompt: String
    let updatedAt: Date

    init(thread: DiscussionThread) {
        id = thread.id
        targetType = thread.nodeID.targetType
        targetID = thread.nodeID.targetID
        title = thread.title
        subtitle = thread.subtitle
        starterPrompt = thread.starterPrompt
        updatedAt = thread.lastUpdated
    }

    var appModel: DiscussionThread {
        DiscussionThread(
            id: id,
            nodeID: ContentNodeID(targetType: targetType, targetID: targetID),
            title: title,
            subtitle: subtitle,
            starterPrompt: starterPrompt,
            lastUpdated: updatedAt
        )
    }
}

private struct RemoteDiscussionCommentRecord: Codable {
    let id: String
    let threadID: String
    let authorID: String
    let authorName: String
    let body: String
    let isPinned: Bool
    let createdAt: Date
    let editedAt: Date?
}

private struct RemoteCommentLikeRecord: Codable {
    let id: String
    let threadID: String
    let commentID: String
    let userID: String
    let createdAt: Date
}

private struct RemoteCommentReportRecord: Codable {
    let id: String
    let threadID: String
    let commentID: String
    let reporterID: String
    let reason: String
    let createdAt: Date

    var appModel: CommentReport {
        CommentReport(
            id: id,
            threadID: threadID,
            commentID: commentID,
            reason: reason,
            createdAt: createdAt
        )
    }
}

private struct RemoteCommentUpdatePayload: Codable {
    let body: String
    let editedAt: Date
}

// MARK: - Content Moderation

enum ContentModerationFilter {
    static func containsBannedContent(_ text: String) -> Bool {
        let lower = text.lowercased()
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "@", with: "a")
        return bannedWords.contains { lower.contains($0) }
    }

    // Turkish + English profanity / hate speech core list
    private static let bannedWords: [String] = [
        "orospu", "kahpe", "ibne", "yarrak", "sikiş", "sikiy", "götü", "oçu",
        "piçin", "gavat", "amcık", "dölü", "zenci", "kafir", "gerizekal",
        "nigger", "faggot", "cunt", "slut", "whore", "retard",
        "fuck", "bitch", "asshole", "bastard"
    ]
}
