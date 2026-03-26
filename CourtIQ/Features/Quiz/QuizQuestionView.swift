import SwiftUI

struct QuizQuestionView: View {
    let question: QuizQuestion
    let questionIndex: Int
    let totalQuestions: Int
    let selectedOptionID: String?
    let showExplanation: Bool
    let isPremium: Bool
    let onSelect: (String) -> Void
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProgressView(value: Double(questionIndex + 1), total: Double(totalQuestions))
                    .tint(CourtIQTheme.accent)

                Text("Q\(questionIndex + 1) / \(totalQuestions)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(question.scenarioText)
                    .font(.body)
                    .lineSpacing(5)

                VStack(spacing: 10) {
                    ForEach(question.options) { option in
                        OptionButton(
                            option: option,
                            isSelected: selectedOptionID == option.id,
                            isCorrect: option.id == question.correctOptionID,
                            isRevealed: showExplanation,
                            onTap: { onSelect(option.id) }
                        )
                    }
                }

                if showExplanation {
                    VStack(alignment: .leading, spacing: 8) {
                        if isPremium || !question.isPremiumExplanation {
                            Label(String(localized: "Explanation"), systemImage: "info.circle.fill")
                                .font(.headline)
                            Text(question.explanation)
                                .font(.callout)
                                .lineSpacing(4)
                        } else {
                            PremiumUpsellBanner(message: String(localized: "Upgrade to Premium to unlock detailed explanations."))
                        }
                    }
                    .padding()
                    .cardStyle()

                    Button(String(localized: "Next")) { onNext() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding()
        }
    }
}

private struct OptionButton: View {
    let option: QuizOption
    let isSelected: Bool
    let isCorrect: Bool
    let isRevealed: Bool
    let onTap: () -> Void

    private var backgroundColor: Color {
        guard isRevealed else { return Color(.secondarySystemBackground) }
        if isCorrect { return .green.opacity(0.2) }
        if isSelected { return .red.opacity(0.2) }
        return Color(.secondarySystemBackground)
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(option.text)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if isRevealed {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : (isSelected ? "xmark.circle.fill" : ""))
                        .foregroundStyle(isCorrect ? .green : .red)
                }
            }
            .padding()
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? CourtIQTheme.accent : .clear, lineWidth: 2)
            )
        }
        .disabled(isRevealed)
    }
}
