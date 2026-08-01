@testable import AppTemplate
import Testing

/// Records calls instead of discarding them like `NoOpAlertService` — lets a test assert
/// a toast was actually shown, not just that the ViewModel didn't crash.
@MainActor
private final class SpyAlertService: AlertService {
    private(set) var toastMessages: [String] = []

    func showAlert(_ alert: AlertContent) {}

    func showToast(_ toast: ToastContent) {
        toastMessages.append(toast.message)
    }
}

@MainActor
struct AddEditItemViewModelTests {
    private func makeViewModel(
        mode: FormMode<Item>,
        repository: ItemRepository = MockItemRepositoryImpl(),
        priorityRepository: PriorityRepository = MockPriorityRepositoryImpl(),
        alertService: AlertService? = nil
    ) -> AddEditItemViewModel {
        AddEditItemViewModel(
            mode: mode,
            repository: repository,
            priorityRepository: priorityRepository,
            alertService: alertService ?? NoOpAlertService()
        )
    }

    @Test
    func saveFailsValidationForEmptyTitle() async {
        let viewModel = makeViewModel(mode: .create)
        viewModel.title = "   "
        viewModel.detail = "Some detail"

        let saved = await viewModel.save()

        #expect(saved == nil)
        #expect(viewModel.validationError == .validation(.emptyField("Title")))
    }

    @Test
    func saveCreatesItemWhenValid() async {
        let repository = MockItemRepositoryImpl()
        let alertService = SpyAlertService()
        let viewModel = makeViewModel(mode: .create, repository: repository, alertService: alertService)
        viewModel.title = "Valid Title"
        viewModel.detail = "Valid detail"

        let saved = await viewModel.save()

        #expect(saved?.title == "Valid Title")
        #expect(viewModel.validationError == nil)
        #expect(alertService.toastMessages == [AppStrings.itemSaved])
    }

    @Test
    func saveUpdatesExistingItemInEditMode() async throws {
        let repository = MockItemRepositoryImpl()
        let original = try #require(await repository.fetchItem(id: "1"))
        let viewModel = makeViewModel(mode: .edit(original), repository: repository)
        viewModel.title = "Updated Title"

        let saved = await viewModel.save()

        #expect(saved?.id == original.id)
        #expect(saved?.title == "Updated Title")
    }

    @Test
    func loadPrioritiesPopulatesOptionsFromRepository() async {
        let viewModel = makeViewModel(mode: .create)
        await viewModel.loadPriorities()

        guard case .loaded(let priorities) = viewModel.priorityOptions else {
            Issue.record("Expected .loaded, got \(viewModel.priorityOptions)")
            return
        }
        #expect(priorities.count == MockPriorityRepositoryImpl.samplePriorities.count)
    }

    @Test
    func editModePrefillsSelectedPriorityFromTheItem() {
        let item = Item(id: "1", title: "Title", detail: "Detail", priorityID: "high")
        let viewModel = makeViewModel(mode: .edit(item))

        #expect(viewModel.selectedPriorityID == "high")
    }

    @Test
    func saveIncludesSelectedPriorityID() async {
        let repository = MockItemRepositoryImpl()
        let viewModel = makeViewModel(mode: .create, repository: repository)
        viewModel.title = "Valid Title"
        viewModel.detail = "Valid detail"
        viewModel.selectedPriorityID = "urgent"

        let saved = await viewModel.save()

        #expect(saved?.priorityID == "urgent")
    }
}
