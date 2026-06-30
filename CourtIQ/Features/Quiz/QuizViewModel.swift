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
    /// Tracks correctness per-question so the completion summary can
    /// carry a tactical-category breakdown that feeds the user's
    /// Tactical Profile alongside the drill data.
    private var perQuestionCorrect: [String: Bool] = [:]

    init(quiz: Quiz, onComplete: ((QuizCompletionSummary) -> Void)? = nil) {
        self.quiz = quiz
        self.onComplete = onComplete
        restoreProgress()
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
        \(score)/\(total) on today's DropVolley quiz — \(quiz.focusLabel).
        Train your tennis IQ daily: courtiq.app
        #DropVolley #TennisIQ
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
        Training daily with DropVolley 👇
        courtiq.app #DropVolley #TennisIQ
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
        let correct = selectedAnswerIsCorrect
        if correct { score += 1 }
        // Record the per-question outcome for tactical bucketing.
        if let q = currentQuestion {
            perQuestionCorrect[q.id] = correct
        }
        persistProgress()
        Task { @MainActor in
            correct ? Haptics.success() : Haptics.error()
        }
    }

    private func advance() {
        guard hasSubmittedCurrentAnswer else { return }
        if isLastQuestion {
            isCompleted = true
            clearPersistedProgress()
            triggerCompletionOnce()
            return
        }
        currentIndex += 1
        selectedIndex = nil
        hasSubmittedCurrentAnswer = false
        persistProgress()
    }

    private func restart() {
        currentIndex = 0
        selectedIndex = nil
        hasSubmittedCurrentAnswer = false
        isCompleted = false
        score = 0
        completionHandled = false
        clearPersistedProgress()
    }

    private func triggerCompletionOnce() {
        guard !completionHandled else { return }
        completionHandled = true
        // Completion peak moment — celebrate a clean sweep, otherwise a
        // positive landing. (Per-question haptics already fire on submit.)
        Task { @MainActor in
            score == quiz.questions.count ? Haptics.celebrate() : Haptics.success()
            // Ask for an App Store review after a genuinely good result (a
            // satisfaction moment). Gated + capped inside RatingPrompt. This is
            // a FREE, high-volume surface, so it's our main ratings driver.
            if score * 5 >= quiz.questions.count * 3 {   // >= 60%
                RatingPrompt.registerWin()
            }
        }
        onComplete?(QuizCompletionSummary(
            quizID: quiz.id,
            title: quiz.title,
            focusLabel: quiz.focusLabel,
            score: score,
            totalQuestions: quiz.questions.count,
            mistakeTypes: quiz.primaryMistakeTypes,
            tacticalBuckets: buildTacticalBuckets()
        ))
    }

    /// Aggregate per-question correctness into TacticalCategory buckets.
    /// Falls back to `.patterns` for questions without a tacticalCategory
    /// hint so older bundled content still contributes meaningfully.
    private func buildTacticalBuckets() -> [QuizTacticalBucket] {
        var sums: [String: (correct: Int, total: Int)] = [:]
        for q in quiz.questions {
            let cat = q.tacticalCategory ?? TacticalCategory.fallback.rawValue
            let prev = sums[cat] ?? (0, 0)
            let wasCorrect = perQuestionCorrect[q.id] ?? false
            sums[cat] = (prev.correct + (wasCorrect ? 1 : 0), prev.total + 1)
        }
        return sums.map { (cat, row) in
            QuizTacticalBucket(category: cat, correct: row.correct, total: row.total)
        }
    }

    // MARK: - Persistence
    //
    // Mid-quiz progress is saved per-quiz-id in UserDefaults so users who
    // background the app or get a call mid-quiz can resume from the next
    // unanswered question with their current score intact.

    private var progressKey: String {
        "CourtIQ.quizProgress.\(quiz.id)"
    }

    private struct PersistedProgress: Codable {
        var currentIndex: Int
        var score: Int
        var savedAt: TimeInterval
    }

    private func persistProgress() {
        // Only persist if user has at least one answered question and the
        // quiz isn't already completed.
        guard currentIndex > 0 || hasSubmittedCurrentAnswer, !isCompleted else { return }
        let p = PersistedProgress(currentIndex: currentIndex,
                                  score: score,
                                  savedAt: Date().timeIntervalSince1970)
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }

    private func restoreProgress() {
        guard let data = UserDefaults.standard.data(forKey: progressKey),
              let p = try? JSONDecoder().decode(PersistedProgress.self, from: data)
        else { return }

        // Stale progress (>48h) is discarded — the daily quiz changes daily
        // so resuming yesterday's questions would be confusing.
        let age = Date().timeIntervalSince1970 - p.savedAt
        guard age < 60 * 60 * 48 else {
            clearPersistedProgress()
            return
        }

        // Sanity check: index must be inside the current quiz's bounds.
        guard p.currentIndex < quiz.questions.count else {
            clearPersistedProgress()
            return
        }

        currentIndex = p.currentIndex
        score = p.score
        // Always resume on a fresh, unanswered question.
        selectedIndex = nil
        hasSubmittedCurrentAnswer = false
    }

    private func clearPersistedProgress() {
        UserDefaults.standard.removeObject(forKey: progressKey)
    }
}
