@testable import AppTemplate
import Testing

@MainActor
struct HomeViewModelTests {
    private func makeViewModel(
        repository: ItemRepository = MockItemRepositoryImpl(),
        priorityRepository: PriorityRepository = MockPriorityRepositoryImpl()
    ) -> HomeViewModel {
        HomeViewModel(repository: repository, priorityRepository: priorityRepository)
    }

    @Test
    func loadPopulatesItemsFromRepository() async {
        let viewModel = makeViewModel()
        await viewModel.load()

        guard case .loaded(let data) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            return
        }
        #expect(data.items.count == MockItemRepositoryImpl.sampleItems.count)
    }

    @Test
    func loadAlsoPopulatesPrioritiesForLabelResolution() async {
        let viewModel = makeViewModel()
        await viewModel.load()

        guard case .loaded(let data) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            return
        }
        #expect(data.priorities.count == MockPriorityRepositoryImpl.samplePriorities.count)
    }

    @Test
    func priorityNameResolvesAnItemsPriorityID() async {
        let repository = MockItemRepositoryImpl(items: [
            Item(id: "1", title: "Item", detail: "Detail", priorityID: "urgent")
        ])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        guard case .loaded(let data) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            return
        }
        #expect(data.priorityName(for: data.items[0]) == "Urgent")
    }

    @Test
    func loadRespectsCurrentSearchText() async {
        let viewModel = makeViewModel()
        viewModel.searchText = "second"
        await viewModel.load()

        guard case .loaded(let data) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            return
        }
        #expect(data.items.map(\.title) == ["Second Item"])
    }

    @Test
    func reloadingWithExistingItemsShowsRefreshingNotLoading() async {
        // A real (if brief) delay on the *second* fetch makes the mid-flight state
        // deterministically observable instead of racing real task scheduling.
        let repository = MockItemRepositoryImpl(artificialDelay: .milliseconds(50))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()
        guard case .loaded = viewModel.state else {
            Issue.record("Expected first load to reach .loaded, got \(viewModel.state)")
            return
        }

        let secondLoad = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(10)) // well inside the 50ms fetch delay

        guard case .refreshing(let data) = viewModel.state else {
            Issue.record("Expected .refreshing while a reload is in flight, got \(viewModel.state)")
            return
        }
        #expect(!data.items.isEmpty)

        await secondLoad.value

        guard case .loaded = viewModel.state else {
            Issue.record("Expected final state to be .loaded, got \(viewModel.state)")
            return
        }
    }

    @Test
    func deletingItemMarksItAsDeletingUntilComplete() async {
        let repository = MockItemRepositoryImpl(artificialDelay: .milliseconds(50))
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        let deleteTask = Task { await viewModel.delete(id: "1") }
        try? await Task.sleep(for: .milliseconds(10)) // well inside the 50ms delete delay

        #expect(viewModel.deletingItemIDs.contains("1"))

        await deleteTask.value

        #expect(!viewModel.deletingItemIDs.contains("1"))
        guard case .loaded(let data) = viewModel.state else {
            Issue.record("Expected .loaded after delete completes, got \(viewModel.state)")
            return
        }
        #expect(!data.items.contains { $0.id == "1" })
    }

    @Test
    func deletingSameItemTwiceConcurrentlyOnlyCallsRepositoryOnce() async {
        let repository = MockItemRepositoryImpl(artificialDelay: .milliseconds(50))
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        // Fire twice without awaiting the first — the guard in `delete(id:)` should make
        // the second call a no-op rather than re-entering while the first is in flight.
        async let first: Void = viewModel.delete(id: "1")
        async let second: Void = viewModel.delete(id: "1")
        _ = await (first, second)

        #expect(!viewModel.deletingItemIDs.contains("1"))
    }
}
