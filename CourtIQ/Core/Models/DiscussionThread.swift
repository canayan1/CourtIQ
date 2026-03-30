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

struct ContentDiscussionThread: Identifiable, Codable {
    let id: String
    let targetType: DiscussionTargetType
    let targetID: String
    let title: String
    let commentCount: Int
    let lastUpdated: Date
}

struct DiscussionRepository {
    static let sampleThreads: [ContentDiscussionThread] = [
        ContentDiscussionThread(
            id: "thread-quiz-serve_001",
            targetType: .quizItem,
            targetID: "serve_001",
            title: "Second serve pressure choices",
            commentCount: 4,
            lastUpdated: Date()
        ),
        ContentDiscussionThread(
            id: "thread-training-daily",
            targetType: .trainingSession,
            targetID: "daily-training",
            title: "Daily decision workflow",
            commentCount: 2,
            lastUpdated: Date()
        ),
        ContentDiscussionThread(
            id: "thread-mobility-quick-reset-001",
            targetType: .mobilityFlow,
            targetID: "quick-reset-001",
            title: "Serve Shoulder Reset feedback",
            commentCount: 3,
            lastUpdated: Date()
        ),
        ContentDiscussionThread(
            id: "thread-premium-recovery",
            targetType: .premiumInsight,
            targetID: "mobility-library",
            title: "Recovery flow value",
            commentCount: 1,
            lastUpdated: Date()
        )
    ]

    static func threadCount(for targetType: DiscussionTargetType, targetID: String) -> Int {
        sampleThreads
            .first { $0.targetType == targetType && $0.targetID == targetID }
            .map { $0.commentCount } ?? 0
    }

    static func summary(for targetType: DiscussionTargetType, targetID: String) -> ContentDiscussionThread? {
        sampleThreads.first { $0.targetType == targetType && $0.targetID == targetID }
    }
}
