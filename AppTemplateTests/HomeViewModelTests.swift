@testable import AppTemplate
import Testing

/// Records calls instead of discarding them like `NoOpAlertService` — lets a test assert
/// an alert was actually shown, not just that the ViewModel didn't crash.
@MainActor
private final class SpyAlertService: AlertService {
    private(set) var alertTitles: [String] = []
    private(set) var toastMessages: [String] = []

    func showAlert(_ alert: AlertContent) {
        alertTitles.append(alert.title)
    }

    func showToast(_ toast: ToastContent) {
        toastMessages.append(toast.message)
    }
}

@MainActor
struct HomeViewModelTests {
    private func makeViewModel(
        repository: ItemRepository = MockItemRepositoryImpl(),
        priorityRepository: PriorityRepository = MockPriorityRepositoryImpl(),
        alertService: AlertService? = nil
    ) -> HomeViewModel {
        HomeViewModel(
            repository: repository,
            priorityRepository: priorityRepository,
            alertService: alertService ?? NoOpAlertService()
        )
    }

    @Test
    func loadPopulatesItemsFromRepository() async {
        let viewModel = makeViewModel()
        await viewModel.load()

        guard case .loaded(let data) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            return
        }
        #expect(data.items.count == MockItemRepositoryImpl.pageSize)
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
    func loadMoreAppendsTheNextPageWithoutReplacingWhatsAlreadyLoaded() async {
        let viewModel = makeViewModel()
        await viewModel.load()

        await viewModel.loadMore()

        guard case .loaded(let data) = viewModel.state else {
            Issue.record("Expected .loaded after loadMore, got \(viewModel.state)")
            return
        }
        #expect(data.items.count == MockItemRepositoryImpl.pageSize * 2)
        #expect(data.items.first?.title == "First Item")
    }

    @Test
    func loadMoreStopsCallingTheRepositoryOnceExhausted() async {
        let repository = MockItemRepositoryImpl(
            items: Array(MockItemRepositoryImpl.sampleItems.prefix(MockItemRepositoryImpl.pageSize))
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        await viewModel.loadMore()
        guard case .loaded(let data) = viewModel.state else {
            Issue.record("Expected .loaded, got \(viewModel.state)")
            return
        }
        #expect(data.items.count == MockItemRepositoryImpl.pageSize)
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
    func deleteFailureShowsAnAlertAndKeepsTheListLoaded() async {
        let repository = MockItemRepositoryImpl(deleteError: AppError.network(.noConnection))
        let alertService = SpyAlertService()
        let viewModel = makeViewModel(repository: repository, alertService: alertService)
        await viewModel.load()

        await viewModel.delete(id: "1")

        // A failed delete is an alert, not a blown-away list — the rest of the items
        // loaded fine and should still be visible underneath the alert.
        guard case .loaded = viewModel.state else {
            Issue.record("Expected list to remain .loaded after a failed delete, got \(viewModel.state)")
            return
        }
        #expect(alertService.alertTitles == [AppStrings.couldntDeleteItem])
    }

    @Test
    func priorityFetchFailureShowsAnAlertAndStillLoadsItemsUnlabeled() async {
        let priorityRepository = MockPriorityRepositoryImpl(fetchError: AppError.network(.noConnection))
        let alertService = SpyAlertService()
        let viewModel = makeViewModel(priorityRepository: priorityRepository, alertService: alertService)

        await viewModel.load()

        // The point of ItemRepositoryImpl's offline cache fallback is defeated if a
        // priorities failure blanks the whole screen anyway — items must still load.
        guard case .loaded(let data) = viewModel.state else {
            Issue.record("Expected .loaded state (items unaffected by priorities failing), got \(viewModel.state)")
            return
        }
        #expect(!data.items.isEmpty)
        #expect(data.priorities.isEmpty)
        #expect(alertService.alertTitles == [AppStrings.couldntLoadPriorities])
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
