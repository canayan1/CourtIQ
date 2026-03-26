import SwiftUI

struct QuizListView: View {
    @Environment(DIContainer.self) private var container
    @State private var viewModel = QuizListViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.quizzes, id: \.id) { quiz in
                NavigationLink {
                    QuizView(quiz: quiz)
                } label: {
                    QuizRowView(quiz: quiz)
                }
                .disabled(!canAccess(quiz))
                .overlay(alignment: .trailing) {
                    if !canAccess(quiz) {
                        PremiumBadge()
                            .padding(.trailing, 8)
                    }
                }
            }
            .navigationTitle(String(localized: "Quizzes"))
            .task { await viewModel.loadQuizzes(quizService: container.quizService) }
            .overlay {
                if viewModel.isLoading { LoadingView() }
            }
        }
    }

    private func canAccess(_ quiz: Quiz) -> Bool {
        !quiz.isPremium || container.premiumGate.isPremium
    }
}

private struct QuizRowView: View {
    let quiz: Quiz

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(quiz.title).font(.headline)
            HStack {
                Label(quiz.difficulty.rawValue, systemImage: "chart.bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(quiz.category.rawValue, systemImage: quiz.category.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(quiz.questions.count) \(String(localized: "questions"))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
