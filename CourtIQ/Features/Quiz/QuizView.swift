import SwiftUI

struct QuizView: View {
    @StateObject private var viewModel: QuizViewModel
    private let title: String

    init(quiz: Quiz, title: String? = nil, onComplete: ((QuizCompletionSummary) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: QuizViewModel(quiz: quiz, onComplete: onComplete))
        self.title = title ?? quiz.title
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard

                if viewModel.isCompleted {
                    completionCard
                } else if let question = viewModel.currentQuestion {
                    questionCard(question)
                    answerOptions(question)
                    feedbackCard
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            primaryActionBar
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.bold())
                    Text(viewModel.progressLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !viewModel.quiz.questions.isEmpty {
                    Text("\(viewModel.score)/\(viewModel.quiz.questions.count)")
                        .font(.headline.monospacedDigit())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                }
            }

            ProgressView(value: viewModel.progressValue)
                .tint(.white)
        }
        .foregroundStyle(.white)
        .padding()
        .background(
            AppPalette.heroGradient
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func questionCard(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(question.category.title, systemImage: question.category.systemImage)
                Spacer()
                Text(question.difficulty.title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(question.focusTag.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.clayBright)
                Text(question.scenario)
                    .font(.title3.weight(.semibold))
            }
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func answerOptions(_ question: QuizQuestion) -> some View {
        VStack(spacing: 12) {
            ForEach(question.options.indices, id: \.self) { index in
                Button {
                    viewModel.selectOption(index)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: iconName(for: index))
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(question.options[index])
                                .font(.body.weight(.semibold))
                                .multilineTextAlignment(.leading)

                            if viewModel.hasSubmittedCurrentAnswer && index == question.correctAnswerIndex {
                                Text("Best percentage choice")
                                    .font(.caption)
                            } else if viewModel.hasSubmittedCurrentAnswer && viewModel.selectedIndex == index && index != question.correctAnswerIndex {
                                Text("This would make the point harder.")
                                    .font(.caption)
                            }
                        }

                        Spacer()
                    }
                    .foregroundStyle(foregroundColor(for: index))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(backgroundColor(for: index))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(borderColor(for: index), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.hasSubmittedCurrentAnswer)
            }
        }
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.feedbackTitle)
                .font(.headline)
            Text(viewModel.feedbackBody)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Session complete", systemImage: "checkmark.seal.fill")
                .font(.title3.bold())
                .foregroundStyle(AppPalette.moss)

            Text(viewModel.completionSummary)
                .font(.title3.weight(.semibold))

            Text("Review the explanations, then run it again or head back to today’s plan for your next block.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No quiz available")
                .font(.headline)
            Text("Add questions to this category to start a practice block.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var primaryActionBar: some View {
        VStack {
            Button(action: viewModel.handlePrimaryAction) {
                Text(viewModel.primaryButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmit && !viewModel.hasSubmittedCurrentAnswer && !viewModel.isCompleted)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.thinMaterial)
    }

    private func iconName(for index: Int) -> String {
        switch viewModel.optionState(for: index) {
        case .idle:
            return "circle"
        case .selected:
            return "largecircle.fill.circle"
        case .correct:
            return "checkmark.circle.fill"
        case .incorrect:
            return "xmark.circle.fill"
        }
    }

    private func foregroundColor(for index: Int) -> Color {
        switch viewModel.optionState(for: index) {
        case .correct:
            return AppPalette.moss
        case .incorrect:
            return AppPalette.alert
        default:
            return .primary
        }
    }

    private func backgroundColor(for index: Int) -> Color {
        switch viewModel.optionState(for: index) {
        case .selected:
            return AppPalette.sand.opacity(0.45)
        case .correct:
            return AppPalette.moss.opacity(0.16)
        case .incorrect:
            return AppPalette.alert.opacity(0.16)
        case .idle:
            return AppPalette.parchment
        }
    }

    private func borderColor(for index: Int) -> Color {
        switch viewModel.optionState(for: index) {
        case .selected:
            return AppPalette.clay
        case .correct:
            return AppPalette.moss
        case .incorrect:
            return AppPalette.alert
        case .idle:
            return AppPalette.sand
        }
    }
}
