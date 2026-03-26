import Testing
@testable import CourtIQ

@Suite("FAQViewModel Tests")
struct FAQViewModelTests {
    private let sampleItems: [FAQItem] = [
        FAQItem(id: "1", question: "What is a let?", answer: "A let is when a serve hits the net.", category: .rules),
        FAQItem(id: "2", question: "How is scoring done?", answer: "15, 30, 40, game.", category: .scoring),
    ]

    @Test("Search filters by question text")
    func searchByQuestion() {
        let vm = FAQViewModel()
        vm.allItems = sampleItems
        vm.searchText = "let"
        #expect(vm.filteredItems.count == 1)
        #expect(vm.filteredItems.first?.id == "1")
    }

    @Test("Empty search returns all items")
    func emptySearchReturnsAll() {
        let vm = FAQViewModel()
        vm.allItems = sampleItems
        vm.searchText = ""
        #expect(vm.filteredItems.count == 2)
    }
}
