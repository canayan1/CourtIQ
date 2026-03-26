import SwiftUI

struct QuizView: View {
    @State private var vm = QuizViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isFinished {
                    resultScreen
                } else if let question = vm.currentQuestion {
                    questionScreen(question)
                }
            }
            .navigationTitle(vm.quiz.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Question Screen

    private func questionScreen(_ question: QuizQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ProgressView(value: vm.progress)
                    .tint(.green)

                Text("Q\(vm.currentIndex + 1) of \(vm.quiz.questions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(question.scenarioText)
                    .font(.body)
                    .lineSpacing(5)

                VStack(spacing: 10) {
                    ForEach(question.options) { option in
                        optionButton(option, question: question)
                    }
                }

                if vm.isAnswered {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Explanation", systemImage: "info.circle.fill")
                            .font(.headline)
                        Text(question.explanation)
                            .font(.callout)
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button("Next") { vm.next() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding()
        }
    }

    private func optionButton(_ option: QuizOption, question: QuizQuestion) -> some View {
        let isSelected = vm.selectedOptionID == option.id
        let isCorrect  = option.id == question.correctOptionID
        let revealed   = vm.isAnswered

        var bg: Color {
            guard revealed else { return Color(.secondarySystemBackground) }
            if isCorrect { return .green.opacity(0.2) }
            if isSelected { return .red.opacity(0.2) }
            return Color(.secondarySystemBackground)
        }

        return Button {
            vm.select(optionID: option.id)
        } label: {
            HStack {
                Text(option.text)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if revealed {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : (isSelected ? "xmark.circle.fill" : ""))
                        .foregroundStyle(isCorrect ? .green : .red)
                }
            }
            .padding()
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .green : .clear, lineWidth: 2)
            )
        }
        .disabled(revealed)
    }

    // MARK: - Result Screen

    private var resultScreen: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: vm.score == vm.quiz.questions.count ? "trophy.fill" : "tennisball.fill")
                .font(.system(size: 72))
                .foregroundStyle(.yellow)
            VStack(spacing: 8) {
                Text("Quiz Complete!")
                    .font(.title.bold())
                Text("\(vm.score) / \(vm.quiz.questions.count) correct")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Play Again") { vm.restart() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 32)
        }
    }
}

// MARK: - Shared Button Style

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
