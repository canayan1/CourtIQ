import SwiftUI

struct TipArchiveView: View {
    @Environment(DIContainer.self) private var container
    @State private var viewModel = TipArchiveViewModel()

    var body: some View {
        List(viewModel.tips, id: \.id) { tip in
            VStack(alignment: .leading, spacing: 6) {
                Label(tip.category.rawValue, systemImage: tip.category.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(tip.title)
                    .font(.headline)
                Text(tip.publishedDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle(String(localized: "Tip Archive"))
        .task {
            await viewModel.loadArchive(tipService: container.tipService)
        }
        .overlay {
            if viewModel.isLoading { LoadingView() }
        }
    }
}
