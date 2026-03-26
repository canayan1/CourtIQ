import Foundation
import Observation

@Observable
final class QuizListViewModel {
    var quizzes: [Quiz] = []
    var isLoading: Bool = false

    func loadQuizzes(quizService: QuizService) async {
        isLoading = true
        defer { isLoading = false }
        do {
            quizzes = try await quizService.fetchQuizzes()
        } catch {
            quizzes = []
        }
    }
}
