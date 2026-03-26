import Testing
@testable import CourtIQ

@Suite("QuizViewModel Tests")
struct QuizViewModelTests {
    private func makeQuiz() -> Quiz {
        Quiz(
            id: "test-quiz",
            title: "Test Quiz",
            description: "A test quiz",
            difficulty: .beginner,
            questions: [
                QuizQuestion(
                    id: "q1",
                    scenarioText: "You are at deuce. Where should you serve?",
                    options: [
                        QuizOption(id: "a", text: "Wide to the backhand"),
                        QuizOption(id: "b", text: "T"),
                        QuizOption(id: "c", text: "Into the body"),
                    ],
                    correctOptionID: "b",
                    explanation: "Serving T at deuce limits the returner's angle.",
                    isPremiumExplanation: false
                )
            ],
            isPremium: false,
            category: .tactics
        )
    }

    @Test("Selecting correct option increments score")
    func selectCorrectOption() {
        let vm = QuizViewModel(quiz: makeQuiz())
        vm.select(optionID: "b")
        #expect(vm.score == 1)
        #expect(vm.showExplanation == true)
    }

    @Test("Selecting wrong option does not increment score")
    func selectWrongOption() {
        let vm = QuizViewModel(quiz: makeQuiz())
        vm.select(optionID: "a")
        #expect(vm.score == 0)
    }

    @Test("Next question after last marks quiz finished")
    func finishesAfterLastQuestion() {
        let vm = QuizViewModel(quiz: makeQuiz())
        vm.select(optionID: "b")
        vm.nextQuestion()
        #expect(vm.isFinished == true)
    }
}
