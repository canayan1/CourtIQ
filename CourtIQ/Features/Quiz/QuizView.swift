import SwiftUI

struct QuizView: View {
    @StateObject private var viewModel: QuizViewModel
    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var notifications = NotificationManager.shared
    @State private var showNotificationPreAsk = false
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
        .onChange(of: viewModel.isCompleted) { _, completed in
            // Pre-ask for daily reminder right after the first quiz completion
            // (highest-intent moment — they just felt the dopamine).
            guard completed else { return }
            Task {
                await notifications.refreshAuthorizationStatus()
                if notifications.shouldShowPreAsk() {
                    showNotificationPreAsk = true
                }
            }
        }
        .sheet(isPresented: $showNotificationPreAsk) {
            NotificationPreAskSheet()
                .environmentObject(lang)
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
        VStack(alignment: .leading, spacing: 0) {
            // Court diagram — editorial-style single court on parchment.
            // QuizCourtDiagramView manages its own height (288pt).
            QuizCourtDiagramView(diagram: question.resolvedDiagram)
                .overlay(alignment: .topTrailing) {
                    Text(question.difficulty.title.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppPalette.ink.opacity(0.85)))
                        .padding(14)
                }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(question.category.title, systemImage: question.category.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(question.focusTag.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppPalette.clayBright)
                    Text(question.localizedScenario(for: lang.language))
                        .font(.title3.weight(.semibold))
                }
            }
            .padding()
            .padding(.top, 4)
        }
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

                        // Per-option "Best choice" / "Harder" footnotes
                        // removed — the icon + color already signal correctness;
                        // the rationale below explains why.
                        Text(localizedOptions[index])
                            .font(.body.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel(
                                viewModel.hasSubmittedCurrentAnswer && index == question.correctAnswerIndex
                                    ? "\(localizedOptions[index]). \(lang.t("quiz.best_choice"))"
                                    : localizedOptions[index]
                            )
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
        // Collapsed: 2-person icon + share button only. Header + 12-word
        // description removed.
        HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(AppPalette.clay)
            ShareLink(item: viewModel.partnerChallengeText(for: question)) {
                Label(lang.t("common.share"), systemImage: "square.and.arrow.up")
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
        // Centered seal + dynamic completion summary. "Session complete"
        // header + 11-word review-hint dropped — the seal + score speak.
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppPalette.moss)
            Text(viewModel.completionSummary)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    /// Share card shown below the completion summary — single button.
    private var shareResultCard: some View {
        ShareLink(item: viewModel.resultShareText) {
            Label(lang.t("common.share"), systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppPalette.clay)
    }

    // MARK: - Empty / Action Bar

    private var emptyState: some View {
        VStack(spacing: 12) {
            TennisGlyph(kind: .racket, color: AppPalette.inkSoft.opacity(0.4), size: 64)
            Text(lang.t("quiz.no_quiz"))
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
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
