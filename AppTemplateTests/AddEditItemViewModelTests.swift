@testable import AppTemplate
import Testing

@MainActor
struct AddEditItemViewModelTests {
    private func makeViewModel(
        mode: AddEditItemViewModel.Mode,
        repository: ItemRepository = MockItemRepositoryImpl(),
        priorityRepository: PriorityRepository = MockPriorityRepositoryImpl()
    ) -> AddEditItemViewModel {
        AddEditItemViewModel(mode: mode, repository: repository, priorityRepository: priorityRepository)
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
        let viewModel = makeViewModel(mode: .create, repository: repository)
        viewModel.title = "Valid Title"
        viewModel.detail = "Valid detail"

        let saved = await viewModel.save()

        #expect(saved?.title == "Valid Title")
        #expect(viewModel.validationError == nil)
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
