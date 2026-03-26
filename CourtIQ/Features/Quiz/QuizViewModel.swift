import Foundation
import Observation

@Observable
final class QuizViewModel {
    private let quiz: Quiz
    private(set) var currentIndex: Int = 0
    private(set) var selectedOptionID: String?
    private(set) var showExplanation: Bool = false
    private(set) var score: Int = 0
    private(set) var isFinished: Bool = false

    var currentQuestion: QuizQuestion? {
        guard currentIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentIndex]
    }

    init(quiz: Quiz) {
        self.quiz = quiz
    }

    func select(optionID: String) {
        guard selectedOptionID == nil else { return }
        selectedOptionID = optionID
        if optionID == currentQuestion?.correctOptionID {
            score += 1
        }
        showExplanation = true
    }

    func nextQuestion() {
        selectedOptionID = nil
        showExplanation = false
        let next = currentIndex + 1
        if next >= quiz.questions.count {
            isFinished = true
        } else {
            currentIndex = next
        }
    }
}
