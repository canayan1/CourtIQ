import SwiftUI
import Charts

struct ProgressView: View {
    @Environment(DIContainer.self) private var container
    @State private var viewModel = ProgressViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    StreakCardView(streakCount: viewModel.streakCount)

                    if !viewModel.recentResults.isEmpty {
                        PerformanceChartView(results: viewModel.recentResults)
                    }

                    QuizHistoryListView(
                        results: viewModel.recentResults,
                        isPremium: container.premiumGate.isPremium
                    )
                }
                .padding()
            }
            .navigationTitle(String(localized: "Progress"))
        }
        .task {
            await viewModel.loadResults(progressService: container.progressService,
                                        authService: container.authService,
                                        premiumGate: container.premiumGate)
        }
    }
}

private struct StreakCardView: View {
    let streakCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(String(localized: "Current Streak"))
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(streakCount) \(String(localized: "days"))")
                    .font(.title.bold())
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
        }
        .cardStyle()
    }
}

private struct PerformanceChartView: View {
    let results: [QuizResult]

    var body: some View {
        VStack(alignment: .leading) {
            Text(String(localized: "Recent Performance"))
                .font(.headline)
            Chart(results.suffix(7), id: \.id) { result in
                BarMark(
                    x: .value("Date", result.completedAt, unit: .day),
                    y: .value("Score %", result.percentage)
                )
                .foregroundStyle(CourtIQTheme.accent)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 160)
        }
        .cardStyle()
    }
}

private struct QuizHistoryListView: View {
    let results: [QuizResult]
    let isPremium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Quiz History"))
                .font(.headline)

            ForEach(results) { result in
                HStack {
                    VStack(alignment: .leading) {
                        Text(result.quizTitle).font(.subheadline)
                        Text(result.completedAt, style: .date)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(result.score)/\(result.totalQuestions)")
                        .font(.headline)
                        .foregroundStyle(result.percentage >= 70 ? .green : .orange)
                }
                .padding(.vertical, 4)
                Divider()
            }

            if !isPremium {
                PremiumUpsellBanner(message: String(localized: "Upgrade to see your full history."))
            }
        }
        .cardStyle()
    }
}
