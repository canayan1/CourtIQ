import Foundation
import SwiftData

@Model
final class QuizResult {
    var id: String
    var quizID: String
    var quizTitle: String
    var score: Int
    var totalQuestions: Int
    var completedAt: Date
    var isSynced: Bool

    var percentage: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(score) / Double(totalQuestions) * 100
    }

    init(quizID: String, quizTitle: String, score: Int, totalQuestions: Int) {
        self.id = UUID().uuidString
        self.quizID = quizID
        self.quizTitle = quizTitle
        self.score = score
        self.totalQuestions = totalQuestions
        self.completedAt = Date()
        self.isSynced = false
    }
}
