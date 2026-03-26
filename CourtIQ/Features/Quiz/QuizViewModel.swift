import Foundation
import Observation

@Observable
final class QuizViewModel {
    let quiz: Quiz
    private(set) var currentIndex: Int = 0
    private(set) var selectedOptionID: String? = nil
    private(set) var score: Int = 0
    private(set) var isFinished: Bool = false

    var currentQuestion: QuizQuestion? {
        guard currentIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentIndex]
    }

    var isAnswered: Bool { selectedOptionID != nil }

    var progress: Double {
        Double(currentIndex) / Double(quiz.questions.count)
    }

    init(quiz: Quiz = .sample) {
        self.quiz = quiz
    }

    func select(optionID: String) {
        guard !isAnswered else { return }
        selectedOptionID = optionID
        if optionID == currentQuestion?.correctOptionID {
            score += 1
        }
    }

    func next() {
        let next = currentIndex + 1
        if next >= quiz.questions.count {
            isFinished = true
        } else {
            currentIndex = next
            selectedOptionID = nil
        }
    }

    func restart() {
        currentIndex = 0
        selectedOptionID = nil
        score = 0
        isFinished = false
    }
}
