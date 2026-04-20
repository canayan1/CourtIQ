import SwiftUI

struct QuizView: View {
    @StateObject private var viewModel: QuizViewModel
    @EnvironmentObject private var lang: LanguageManager
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
                    shareResultCard          // ← Share results
                } else if let question = viewModel.currentQuestion {
                    questionCard(question)
                    answerOptions(question)
                    feedbackCard
                    if viewModel.hasSubmittedCurrentAnswer {
                        partnerChallengeCard(question)  // ← Challenge partner
                    }
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: lang.language, initial: true) { _, newLang in
            viewModel.language = newLang
        }
        .safeAreaInset(edge: .bottom) {
            primaryActionBar
        }
    }

    // MARK: - Header

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
        .background(AppPalette.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Question

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
                Text(question.localizedScenario(for: lang.language))
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

    // MARK: - Answer Options

    private func answerOptions(_ question: QuizQuestion) -> some View {
        VStack(spacing: 12) {
            let localizedOptions = question.localizedOptions(for: lang.language)
            ForEach(question.options.indices, id: \.self) { index in
                Button {
                    viewModel.selectOption(index)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: iconName(for: index))
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(localizedOptions[index])
                                .font(.body.weight(.semibold))
                                .multilineTextAlignment(.leading)

                            if viewModel.hasSubmittedCurrentAnswer && index == question.correctAnswerIndex {
                                Text(lang.t("quiz.best_choice"))
                                    .font(.caption)
                            } else if viewModel.hasSubmittedCurrentAnswer
                                        && viewModel.selectedIndex == index
                                        && index != question.correctAnswerIndex {
                                Text(lang.t("quiz.harder"))
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

    // MARK: - Feedback

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

    // MARK: - Challenge Partner (per question)

    private func partnerChallengeCard(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(lang.t("quiz.challenge_partner"), systemImage: "person.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.clay)

            Text(lang.t("quiz.challenge_desc"))
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)

            ShareLink(item: viewModel.partnerChallengeText(for: question)) {
                Label(lang.t("quiz.send_partner"), systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.clay)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Completion

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(lang.t("quiz.session_complete"), systemImage: "checkmark.seal.fill")
                .font(.title3.bold())
                .foregroundStyle(AppPalette.moss)

            Text(viewModel.completionSummary)
                .font(.title3.weight(.semibold))

            Text(lang.t("quiz.review_hint"))
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

    /// Share card shown below the completion summary.
    private var shareResultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(lang.t("quiz.share_result"), systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.clay)

            Text(lang.t("quiz.share_desc"))
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)

            ShareLink(item: viewModel.resultShareText) {
                Label(lang.t("quiz.share_btn"), systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Empty / Action Bar

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("quiz.no_quiz"))
                .font(.headline)
            Text(lang.t("quiz.no_quiz_desc"))
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

    // MARK: - Option styling helpers

    private func iconName(for index: Int) -> String {
        switch viewModel.optionState(for: index) {
        case .idle:      return "circle"
        case .selected:  return "largecircle.fill.circle"
        case .correct:   return "checkmark.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        }
    }

    private func foregroundColor(for index: Int) -> Color {
        switch viewModel.optionState(for: index) {
        case .correct:   return AppPalette.moss
        case .incorrect: return AppPalette.alert
        default:         return .primary
        }
    }

    private func backgroundColor(for index: Int) -> Color {
        switch viewModel.optionState(for: index) {
        case .selected:  return AppPalette.sand.opacity(0.45)
        case .correct:   return AppPalette.moss.opacity(0.16)
        case .incorrect: return AppPalette.alert.opacity(0.16)
        case .idle:      return AppPalette.parchment
        }
    }

    private func borderColor(for index: Int) -> Color {
        switch viewModel.optionState(for: index) {
        case .selected:  return AppPalette.clay
        case .correct:   return AppPalette.moss
        case .incorrect: return AppPalette.alert
        case .idle:      return AppPalette.sand
        }
    }
}
