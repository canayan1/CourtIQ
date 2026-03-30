import SwiftUI

struct TodayView: View {
    @StateObject private var manager = DailyQuizManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                Text("A quick daily decision workout for club-level tennis. One fresh scenario quiz every day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                dailyCard
                statsRow

                VStack(alignment: .leading, spacing: 12) {
                    Text("How it works")
                        .font(.headline)
                    Text("Answer 5 match-style choices, see instant coaching feedback, and build a smarter court game day by day.")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle("Today")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CourtIQ")
                .font(.largeTitle.bold())
            Text("Today’s CourtIQ")
                .font(.title3.weight(.semibold))
            Text("Train one daily decision in 5 focused questions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today’s focus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(manager.todayQuiz.focusLabel)
                        .font(.title2.weight(.semibold))
                }
                Spacer()
                Label("5 questions", systemImage: "5.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(manager.isCompletedToday ? "You completed today’s session." : "Your daily quiz is ready.")
                .font(.body)
                .foregroundStyle(.secondary)

            NavigationLink {
                QuizView(quiz: manager.todayQuiz) {
                    manager.markCompletedToday()
                }
            } label: {
                Text(manager.isCompletedToday ? "Replay Today’s Quiz" : "Start Today’s Quiz")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statCard(title: "Streak", value: "\(manager.currentStreak) days")
            statCard(title: "Completed", value: "\(manager.totalQuizzesCompleted)")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}
