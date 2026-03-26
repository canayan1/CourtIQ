import Foundation
import Observation

@Observable
final class FAQViewModel {
    var allItems: [FAQItem] = []
    var searchText: String = ""
    var isLoading: Bool = false

    var filteredItems: [FAQItem] {
        guard !searchText.isEmpty else { return allItems }
        return allItems.filter {
            $0.question.localizedCaseInsensitiveContains(searchText) ||
            $0.answer.localizedCaseInsensitiveContains(searchText)
        }
    }

    func items(for category: FAQCategory) -> [FAQItem] {
        allItems.filter { $0.category == category }
    }

    func loadFAQ(faqService: FAQService) async {
        isLoading = true
        defer { isLoading = false }
        do {
            allItems = try await faqService.fetchFAQ()
        } catch {
            allItems = []
        }
    }
}
