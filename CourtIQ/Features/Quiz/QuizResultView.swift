import SwiftUI

struct QuizResultView: View {
    let quiz: Quiz
    let viewModel: QuizViewModel
    @Environment(\.dismiss) private var dismiss

    private var percentage: Double {
        Double(viewModel.score) / Double(quiz.questions.count) * 100
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: percentage >= 70 ? "trophy.fill" : "arrow.counterclockwise.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(percentage >= 70 ? .yellow : CourtIQTheme.accent)

            VStack(spacing: 8) {
                Text(String(localized: "Quiz Complete!"))
                    .font(.title.bold())
                Text("\(viewModel.score) / \(quiz.questions.count)")
                    .font(.largeTitle.bold())
                    .foregroundStyle(CourtIQTheme.accent)
                Text(String(format: "%.0f%%", percentage))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(String(localized: "Done")) { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 32)
        }
        .navigationBarBackButtonHidden()
    }
}
