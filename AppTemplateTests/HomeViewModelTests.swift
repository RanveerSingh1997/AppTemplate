@testable import AppTemplate
import Testing

@MainActor
struct HomeViewModelTests {
    @Test
    func loadPopulatesItemsFromRepository() async {
        let viewModel = HomeViewModel(repository: MockItemRepositoryImpl())
        await viewModel.load()

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            return
        }
        #expect(items.count == MockItemRepositoryImpl.sampleItems.count)
    }
}
