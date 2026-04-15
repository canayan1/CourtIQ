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
    private let threadsKey = "CourtIQ.Discussion.Threads"
    private let commentsKey = "CourtIQ.Discussion.Comments"
    private let reportsKey = "CourtIQ.Discussion.Reports"

    private init() {
        load()
        if threads.isEmpty {
            seed()
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

        let thread = DiscussionThread(
            id: "thread-\(nodeID.targetType.rawValue)-\(nodeID.targetID)",
            nodeID: nodeID,
            title: title,
            subtitle: subtitle,
            starterPrompt: starterPrompt,
            lastUpdated: Date()
        )
        threads.append(thread)
        save()
        return thread
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

    func addComment(body: String, to threadID: String, authorID: String, authorName: String) {
        let comment = DiscussionComment(
            id: UUID().uuidString,
            threadID: threadID,
            authorID: authorID,
            authorName: authorName,
            body: body,
            createdAt: Date(),
            likeCount: 0,
            isPinned: false,
            editedAt: nil
        )

        commentsByThread[threadID, default: []].append(comment)
        touch(threadID: threadID)
        save()
    }

    func updateComment(commentID: String, in threadID: String, body: String) {
        guard var threadComments = commentsByThread[threadID],
              let index = threadComments.firstIndex(where: { $0.id == commentID }) else {
            return
        }

        threadComments[index].body = body
        threadComments[index].editedAt = Date()
        commentsByThread[threadID] = threadComments
        touch(threadID: threadID)
        save()
    }

    func toggleLike(commentID: String, in threadID: String) {
        guard var threadComments = commentsByThread[threadID],
              let index = threadComments.firstIndex(where: { $0.id == commentID }) else {
            return
        }

        threadComments[index].likeCount += 1
        commentsByThread[threadID] = threadComments
        touch(threadID: threadID)
        save()
    }

    func deleteComment(commentID: String, in threadID: String) {
        commentsByThread[threadID]?.removeAll { $0.id == commentID }
        touch(threadID: threadID)
        save()
    }

    func report(commentID: String, in threadID: String, reason: String) {
        reports.append(
            CommentReport(
                id: UUID().uuidString,
                threadID: threadID,
                commentID: commentID,
                reason: reason,
                createdAt: Date()
            )
        )
        save()
    }

    func reset() {
        threads = []
        commentsByThread = [:]
        reports = []
        defaults.removeObject(forKey: threadsKey)
        defaults.removeObject(forKey: commentsKey)
        defaults.removeObject(forKey: reportsKey)
        seed()
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

    private func touch(threadID: String) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[index].lastUpdated = Date()
    }

    private func seed() {
        let seededThreads = [
            DiscussionThread(
                id: "thread-quiz-serve_001",
                nodeID: ContentNodeID(targetType: .quizItem, targetID: "serve_001"),
                title: "Second serve pressure choices",
                subtitle: "How players protect second serves without getting passive.",
                starterPrompt: "What’s your safest second-serve pattern when the scoreboard gets tight?",
                lastUpdated: Date().addingTimeInterval(-7_200)
            ),
            DiscussionThread(
                id: "thread-training-hybrid-foundation",
                nodeID: ContentNodeID(targetType: .trainingSession, targetID: "training-hybrid-foundation"),
                title: "8-week hybrid foundation",
                subtitle: "How players manage soreness, cardio, and explosive work in one weekly plan.",
                starterPrompt: "Which day in the foundation week feels most transferable to your on-court movement?",
                lastUpdated: Date().addingTimeInterval(-18_000)
            ),
            DiscussionThread(
                id: "thread-mobility-quick-reset-001",
                nodeID: ContentNodeID(targetType: .mobilityFlow, targetID: "quick-reset-001"),
                title: "Serve Shoulder Reset",
                subtitle: "How the quick reset changes serve feel before practice or match play.",
                starterPrompt: "Do you use this before serving sessions, after, or both?",
                lastUpdated: Date().addingTimeInterval(-12_000)
            )
        ]

        let seededComments: [String: [DiscussionComment]] = [
            "thread-quiz-serve_001": [
                DiscussionComment(
                    id: "coach-quiz-serve-001",
                    threadID: "thread-quiz-serve_001",
                    authorID: "coach",
                    authorName: "CourtIQ Coach",
                    body: "If your second serve choice still feels rushed, lower the target and simplify the first ball pattern after it.",
                    createdAt: Date().addingTimeInterval(-64_000),
                    likeCount: 8,
                    isPinned: true,
                    editedAt: nil
                ),
                DiscussionComment(
                    id: "player-quiz-serve-001",
                    threadID: "thread-quiz-serve_001",
                    authorID: "seed-player-1",
                    authorName: "Club Baseline",
                    body: "Body spin became way more reliable for me once I paired it with a heavy crosscourt first ball instead of trying to finish instantly.",
                    createdAt: Date().addingTimeInterval(-20_000),
                    likeCount: 3,
                    isPinned: false,
                    editedAt: nil
                )
            ],
            "thread-training-hybrid-foundation": [
                DiscussionComment(
                    id: "coach-training-001",
                    threadID: "thread-training-hybrid-foundation",
                    authorID: "coach",
                    authorName: "CourtIQ Coach",
                    body: "If Day 1 ruins Day 3, the answer is usually volume control, not skipping conditioning entirely.",
                    createdAt: Date().addingTimeInterval(-56_000),
                    likeCount: 5,
                    isPinned: true,
                    editedAt: nil
                )
            ],
            "thread-mobility-quick-reset-001": [
                DiscussionComment(
                    id: "coach-mobility-001",
                    threadID: "thread-mobility-quick-reset-001",
                    authorID: "coach",
                    authorName: "CourtIQ Coach",
                    body: "This reset works best when the movement stays smooth. Don’t turn it into another workout before the serve.",
                    createdAt: Date().addingTimeInterval(-32_000),
                    likeCount: 4,
                    isPinned: true,
                    editedAt: nil
                )
            ]
        ]

        threads = seededThreads
        commentsByThread = seededComments
        save()
    }
}
