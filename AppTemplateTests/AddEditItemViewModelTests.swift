@testable import AppTemplate
import Testing

@MainActor
struct AddEditItemViewModelTests {
    @Test
    func saveFailsValidationForEmptyTitle() async {
        let viewModel = AddEditItemViewModel(mode: .create, repository: MockItemRepositoryImpl())
        viewModel.title = "   "
        viewModel.detail = "Some detail"

        let saved = await viewModel.save()

        #expect(saved == nil)
        #expect(viewModel.validationError == .validation(.emptyField("Title")))
    }

    @Test
    func saveCreatesItemWhenValid() async {
        let repository = MockItemRepositoryImpl()
        let viewModel = AddEditItemViewModel(mode: .create, repository: repository)
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
        let viewModel = AddEditItemViewModel(mode: .edit(original), repository: repository)
        viewModel.title = "Updated Title"

        let saved = await viewModel.save()

        #expect(saved?.id == original.id)
        #expect(saved?.title == "Updated Title")
    }
}
