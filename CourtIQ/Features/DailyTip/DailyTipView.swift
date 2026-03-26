import SwiftUI

struct DailyTipView: View {
    @Environment(DIContainer.self) private var container
    @State private var viewModel = DailyTipViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if let tip = viewModel.todayTip {
                    TipDetailView(tip: tip)
                } else {
                    ContentUnavailableView(
                        String(localized: "No Tip Today"),
                        systemImage: "lightbulb.slash",
                        description: Text(String(localized: "Check back tomorrow!"))
                    )
                }
            }
            .navigationTitle(String(localized: "Daily Tip"))
            .toolbar {
                if container.premiumGate.isPremium {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            TipArchiveView()
                        } label: {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadTodayTip(tipService: container.tipService)
        }
    }
}

private struct TipDetailView: View {
    let tip: DailyTip

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label(tip.category.rawValue, systemImage: tip.category.icon)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(CourtIQTheme.accent.opacity(0.15))
                        .foregroundStyle(CourtIQTheme.accent)
                        .clipShape(Capsule())
                    Spacer()
                }

                Text(tip.title)
                    .font(.title2.bold())

                Text(tip.body)
                    .font(.body)
                    .lineSpacing(6)
            }
            .padding()
        }
    }
}
