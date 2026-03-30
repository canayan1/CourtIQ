import Combine

struct QuizQuestionModel {
    let prompt: String
    let options: [String]
    let correctIndex: Int
}

final class QuizViewModel: ObservableObject {
    @Published private(set) var question: QuizQuestionModel
    @Published private(set) var selectedIndex: Int? = nil
    @Published private(set) var showFeedback = false

    init() {
        self.question = QuizQuestionModel(
            prompt: "Which shot is best after a deep return?",
            options: ["Cross-court forehand", "Drop shot", "Lob"],
            correctIndex: 0
        )
    }

    var hasAnswered: Bool {
        selectedIndex != nil
    }

    var isCorrectSelection: Bool {
        selectedIndex == question.correctIndex
    }

    var feedbackText: String {
        guard let selectedIndex = selectedIndex else {
            return "Select an option and submit."
        }
        return selectedIndex == question.correctIndex ? "Good choice!" : "Try again."
    }

    func select(optionIndex: Int) {
        guard !showFeedback else { return }
        selectedIndex = optionIndex
    }

    func submit() {
        showFeedback = true
    }

    func reset() {
        selectedIndex = nil
        showFeedback = false
    }
}
