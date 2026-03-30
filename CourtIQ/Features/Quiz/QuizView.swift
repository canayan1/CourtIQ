import SwiftUI

struct QuizView: View {

    @StateObject private var viewModel: QuizViewModel
    let onComplete: () -> Void

    init(quiz: Quiz = .sample, onComplete: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: QuizViewModel(quiz: quiz))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(viewModel.quiz.title)
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if viewModel.isFinished {
                finishedView
            } else if let question = viewModel.currentQuestion {
                questionView(question)
            } else {
                Text("No questions available.")
                    .foregroundColor(.secondary)
                    .padding()
            }

            Spacer()
        }
        .padding(.top)
    }

    private func questionView(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Question \(viewModel.currentIndex + 1) of \(viewModel.quiz.questions.count)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(question.scenario)
                .font(.body)
                .multilineTextAlignment(.leading)

            VStack(spacing: 12) {
                ForEach(Array(question.options.enumerated()), id: \.0) { index, option in
                    Button(action: {
                        viewModel.select(optionIndex: index)
                    }) {
                        HStack {
                            Text(option)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if viewModel.isAnswered {
                                if index == question.correctAnswerIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else if viewModel.selectedOptionIndex == index {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isAnswered)
                }
            }

            if viewModel.isAnswered {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Explanation")
                        .font(.headline)
                    Text(question.explanation)
                        .font(.callout)
                    Text(question.takeaway)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)

                Button("Next") {
                    viewModel.next()
                    if viewModel.isFinished {
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
    }

    private var finishedView: some View {
        VStack(spacing: 18) {
            Text("Quiz complete")
                .font(.title3)
                .bold()

            Text("\(viewModel.score) of \(viewModel.quiz.questions.count) correct")
                .font(.body)
                .foregroundColor(.secondary)

            Button("Restart Quiz") {
                viewModel.restart()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
}
