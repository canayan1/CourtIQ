import SwiftUI

struct FAQView: View {
    @Environment(DIContainer.self) private var container
    @State private var viewModel = FAQViewModel()

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.searchText.isEmpty {
                    ForEach(viewModel.filteredItems) { item in
                        FAQRowView(item: item)
                    }
                } else {
                    ForEach(FAQCategory.allCases, id: \.self) { category in
                        let items = viewModel.items(for: category)
                        if !items.isEmpty {
                            Section(header: Label(category.rawValue, systemImage: category.icon)) {
                                ForEach(items) { item in
                                    FAQRowView(item: item)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "FAQ"))
            .searchable(text: $viewModel.searchText, prompt: String(localized: "Search FAQ"))
            .task { await viewModel.loadFAQ(faqService: container.faqService) }
            .overlay {
                if viewModel.isLoading { LoadingView() }
            }
        }
    }
}

private struct FAQRowView: View {
    let item: FAQItem
    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(item.answer)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.vertical, 4)
        } label: {
            Text(item.question)
                .font(.body)
        }
    }
}
