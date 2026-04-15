import Foundation
import Combine

enum QuizOptionState {
    case idle
    case selected
    case correct
    case incorrect
}

@MainActor
final class QuizViewModel: ObservableObject {
    @Published private(set) var quiz: Quiz
    @Published private(set) var currentIndex = 0
    @Published private(set) var selectedIndex: Int?
    @Published private(set) var hasSubmittedCurrentAnswer = false
    @Published private(set) var score = 0
    @Published private(set) var isCompleted = false

    private let onComplete: ((QuizCompletionSummary) -> Void)?
    private var completionHandled = false

    init(quiz: Quiz, onComplete: ((QuizCompletionSummary) -> Void)? = nil) {
        self.quiz = quiz
        self.onComplete = onComplete
    }

    var currentQuestion: QuizQuestion? {
        guard quiz.questions.indices.contains(currentIndex) else { return nil }
        return quiz.questions[currentIndex]
    }

    var progressLabel: String {
        guard !quiz.questions.isEmpty else { return "No questions" }
        return "Question \(currentIndex + 1) of \(quiz.questions.count)"
    }

    var progressValue: Double {
        guard !quiz.questions.isEmpty else { return 0 }
        return Double(currentIndex + (isCompleted ? 1 : 0)) / Double(quiz.questions.count)
    }

    var canSubmit: Bool {
        selectedIndex != nil && !hasSubmittedCurrentAnswer
    }

    var primaryButtonTitle: String {
        if isCompleted {
            return "Restart Quiz"
        }

        if hasSubmittedCurrentAnswer {
            return isLastQuestion ? "Finish Quiz" : "Next Question"
        }

        return "Submit Answer"
    }

    var isLastQuestion: Bool {
        currentIndex == quiz.questions.count - 1
    }

    var selectedAnswerIsCorrect: Bool {
        guard let currentQuestion, let selectedIndex else { return false }
        return selectedIndex == currentQuestion.correctAnswerIndex
    }

    var feedbackTitle: String {
        guard hasSubmittedCurrentAnswer else {
            return "Choose the shot you trust most."
        }

        return selectedAnswerIsCorrect ? "Good read" : "Better option available"
    }

    var feedbackBody: String {
        guard let currentQuestion else {
            return "This quiz does not have any questions yet."
        }

        guard hasSubmittedCurrentAnswer else {
            return currentQuestion.takeaway
        }

        return "\(currentQuestion.explanation) \(currentQuestion.takeaway)"
    }

    var completionSummary: String {
        guard !quiz.questions.isEmpty else { return "Add questions to start training." }
        return "You scored \(score) out of \(quiz.questions.count)."
    }

    func selectOption(_ index: Int) {
        guard !hasSubmittedCurrentAnswer, currentQuestion != nil else { return }
        selectedIndex = index
    }

    func handlePrimaryAction() {
        if isCompleted {
            restart()
        } else if hasSubmittedCurrentAnswer {
            advance()
        } else {
            submit()
        }
    }

    func optionState(for index: Int) -> QuizOptionState {
        guard let currentQuestion else { return .idle }

        if !hasSubmittedCurrentAnswer {
            return selectedIndex == index ? .selected : .idle
        }

        if index == currentQuestion.correctAnswerIndex {
            return .correct
        }

        if selectedIndex == index {
            return .incorrect
        }

        return .idle
    }

    private func submit() {
        guard canSubmit else { return }
        hasSubmittedCurrentAnswer = true

        if selectedAnswerIsCorrect {
            score += 1
        }
    }

    private func advance() {
        guard hasSubmittedCurrentAnswer else { return }

        if isLastQuestion {
            isCompleted = true
            triggerCompletionOnce()
            return
        }

        currentIndex += 1
        selectedIndex = nil
        hasSubmittedCurrentAnswer = false
    }

    private func restart() {
        currentIndex = 0
        selectedIndex = nil
        hasSubmittedCurrentAnswer = false
        isCompleted = false
        score = 0
        completionHandled = false
    }

    private func triggerCompletionOnce() {
        guard !completionHandled else { return }
        completionHandled = true
        onComplete?(QuizCompletionSummary(
            quizID: quiz.id,
            title: quiz.title,
            focusLabel: quiz.focusLabel,
            score: score,
            totalQuestions: quiz.questions.count,
            mistakeTypes: quiz.primaryMistakeTypes
        ))
    }
}
