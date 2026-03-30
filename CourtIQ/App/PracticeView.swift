import SwiftUI

struct PracticeView: View {
    var body: some View {
        List {
            Section {
                Text("Choose a category and practice a small set of smart court decisions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            ForEach(QuizCategory.allCases) { category in
                NavigationLink {
                    QuizView(quiz: Quiz.practiceQuiz(category: category))
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.title)
                                .font(.headline)
                            Text("Practice the smartest choice for \(category.title.lowercased()) situations.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Quiz.practiceQuiz(category: category).questions.count) Q")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Practice")
    }
}
