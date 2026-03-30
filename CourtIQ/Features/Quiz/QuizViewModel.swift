import Combine

final class QuizViewModel: ObservableObject {
    let quiz: Quiz
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var selectedOptionIndex: Int? = nil
    @Published private(set) var score: Int = 0
    @Published private(set) var isFinished: Bool = false

    var currentQuestion: QuizQuestion? {
        guard currentIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentIndex]
    }

    var isAnswered: Bool { selectedOptionIndex != nil }

    var progress: Double {
        guard quiz.questions.count > 0 else { return 0 }
        return Double(currentIndex) / Double(quiz.questions.count)
    }

    init(quiz: Quiz = .sample) {
        self.quiz = quiz
    }

    func select(optionIndex: Int) {
        guard !isAnswered else { return }
        selectedOptionIndex = optionIndex
        if optionIndex == currentQuestion?.correctAnswerIndex {
            score += 1
        }
    }

    func next() {
        let next = currentIndex + 1
        if next >= quiz.questions.count {
            isFinished = true
        } else {
            currentIndex = next
            selectedOptionIndex = nil
        }
    }

    func restart() {
        currentIndex = 0
        selectedOptionIndex = nil
        score = 0
        isFinished = false
    }
}
