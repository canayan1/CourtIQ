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
    var language: AppLanguage = .english

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
        guard !quiz.questions.isEmpty else { return t("quiz.no_questions") }
        return String(format: t("quiz.question_of"), currentIndex + 1, quiz.questions.count)
    }

    var progressValue: Double {
        guard !quiz.questions.isEmpty else { return 0 }
        return Double(currentIndex + (isCompleted ? 1 : 0)) / Double(quiz.questions.count)
    }

    var canSubmit: Bool {
        selectedIndex != nil && !hasSubmittedCurrentAnswer
    }

    var primaryButtonTitle: String {
        if isCompleted          { return t("quiz.restart") }
        if hasSubmittedCurrentAnswer {
            return isLastQuestion ? t("quiz.finish") : t("quiz.next")
        }
        return t("quiz.submit")
    }

    var isLastQuestion: Bool {
        currentIndex == quiz.questions.count - 1
    }

    var selectedAnswerIsCorrect: Bool {
        guard let currentQuestion, let selectedIndex else { return false }
        return selectedIndex == currentQuestion.correctAnswerIndex
    }

    var feedbackTitle: String {
        guard hasSubmittedCurrentAnswer else { return t("quiz.choose") }
        return selectedAnswerIsCorrect ? t("quiz.good_read") : t("quiz.better_option")
    }

    var feedbackBody: String {
        guard let currentQuestion else { return t("quiz.no_questions") }
        guard hasSubmittedCurrentAnswer else { return currentQuestion.localizedTakeaway(for: language) }
        return "\(currentQuestion.localizedExplanation(for: language)) \(currentQuestion.localizedTakeaway(for: language))"
    }

    var completionSummary: String {
        guard !quiz.questions.isEmpty else { return t("quiz.no_questions") }
        return String(format: t("quiz.score"), score, quiz.questions.count)
    }

    private func t(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main.path(forResource: "en", ofType: "lproj")
                .flatMap { Bundle(path: $0) }?
                .localizedString(forKey: key, value: key, table: nil) ?? key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    // MARK: - Sharing

    /// Result share text for the completion card.
    var resultShareText: String {
        let total = quiz.questions.count
        let emoji: String
        switch score {
        case total:        emoji = "🎾 Perfect score!"
        case (total/2)...: emoji = "🎾 Solid read."
        default:           emoji = "🎾 Good practice."
        }
        return """
        \(emoji)
        \(score)/\(total) on today's CourtIQ quiz — \(quiz.focusLabel).
        Train your tennis IQ daily: courtiq.app
        #CourtIQ #TennisIQ
        """
    }

    /// Question share text for the "challenge your doubles partner" button.
    /// Only available after the current answer has been submitted.
    func partnerChallengeText(for question: QuizQuestion) -> String {
        let options = question.options.enumerated()
            .map { i, opt in "\(["A", "B", "C", "D"][i]). \(opt)" }
            .joined(separator: "\n")

        return """
        🎾 Tennis IQ challenge — can you solve this?

        "\(question.scenario)"

        \(options)

        What's your call? (DM me the answer)
        Training daily with CourtIQ 👇
        courtiq.app #CourtIQ #TennisIQ
        """
    }

    // MARK: - Actions

    func selectOption(_ index: Int) {
        guard !hasSubmittedCurrentAnswer, currentQuestion != nil else { return }
        selectedIndex = index
    }

    func handlePrimaryAction() {
        if isCompleted       { restart() }
        else if hasSubmittedCurrentAnswer { advance() }
        else                 { submit() }
    }

    func optionState(for index: Int) -> QuizOptionState {
        guard let currentQuestion else { return .idle }
        if !hasSubmittedCurrentAnswer {
            return selectedIndex == index ? .selected : .idle
        }
        if index == currentQuestion.correctAnswerIndex { return .correct }
        if selectedIndex == index                      { return .incorrect }
        return .idle
    }

    private func submit() {
        guard canSubmit else { return }
        hasSubmittedCurrentAnswer = true
        if selectedAnswerIsCorrect { score += 1 }
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
