import SwiftUI

struct QuizView: View {
    @StateObject private var viewModel = QuizViewModel()
    let title: String

    init(title: String = "Quiz") {
        self.title = title
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title2)
                .bold()
                .padding(.top)

            Text(viewModel.question.prompt)
                .font(.title3)
                .multilineTextAlignment(.leading)

            VStack(spacing: 12) {
                ForEach(viewModel.question.options.indices, id: \.self) { index in
                    Button(action: {
                        viewModel.select(optionIndex: index)
                    }) {
                        HStack {
                            Text(viewModel.question.options[index])
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.hasAnswered)
                }
            }

            if viewModel.showFeedback {
                Text(viewModel.feedbackText)
                    .foregroundColor(viewModel.isCorrectSelection ? .green : .red)
                    .padding(.top)
            }

            Button(viewModel.hasAnswered ? "Reset" : "Submit") {
                if viewModel.hasAnswered {
                    viewModel.reset()
                } else {
                    viewModel.submit()
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle(title)
    }
}
