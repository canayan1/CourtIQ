import SwiftUI

struct QuizView: View {
    let quiz: Quiz
    @Environment(DIContainer.self) private var container
    @State private var viewModel: QuizViewModel

    init(quiz: Quiz) {
        self.quiz = quiz
        _viewModel = State(initialValue: QuizViewModel(quiz: quiz))
    }

    var body: some View {
        Group {
            if viewModel.isFinished {
                QuizResultView(quiz: quiz, viewModel: viewModel)
            } else if let question = viewModel.currentQuestion {
                QuizQuestionView(
                    question: question,
                    questionIndex: viewModel.currentIndex,
                    totalQuestions: quiz.questions.count,
                    selectedOptionID: viewModel.selectedOptionID,
                    showExplanation: viewModel.showExplanation,
                    isPremium: container.premiumGate.isPremium,
                    onSelect: viewModel.select(optionID:),
                    onNext: viewModel.nextQuestion
                )
            }
        }
        .navigationTitle(quiz.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.showExplanation)
    }
}
