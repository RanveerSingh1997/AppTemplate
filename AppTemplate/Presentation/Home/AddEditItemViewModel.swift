import Observation

@Observable
@MainActor
final class AddEditItemViewModel {
    var title: String
    var detail: String
    var selectedPriorityID: String?
    private(set) var validationError: AppError?
    private(set) var saveError: AppError?
    private(set) var isSaving = false

    /// Loaded independently of the item form's own fields, via its own `.task` — the
    /// concrete example of composing more than one fetched data source on one screen.
    /// Same `ViewState` pattern as any other fetch-and-show data, just scoped to one
    /// property on a form ViewModel instead of the whole ViewModel.
    private(set) var priorityOptions: ViewState<[Priority]> = .loading

    private let mode: FormMode<Item>
    private let repository: ItemRepository
    private let priorityRepository: PriorityRepository

    init(mode: FormMode<Item>, repository: ItemRepository, priorityRepository: PriorityRepository) {
        self.mode = mode
        self.repository = repository
        self.priorityRepository = priorityRepository
        switch mode {
        case .create:
            title = ""
            detail = ""
            selectedPriorityID = nil
        case .edit(let item):
            title = item.title
            detail = item.detail
            selectedPriorityID = item.priorityID
        }
    }

    var navigationTitle: String {
        switch mode {
        case .create: return AppStrings.newItem
        case .edit: return AppStrings.editItem
        }
    }

    func loadPriorities() async {
        priorityOptions = priorityOptions.value.map(ViewState.refreshing) ?? .loading
        do {
            priorityOptions = .loaded(try await priorityRepository.fetchPriorities())
        } catch {
            priorityOptions = .failed(error.localizedDescription)
        }
    }

    /// Returns the saved item on success, or `nil` if validation/save failed —
    /// check `validationError`/`saveError` for what to show.
    func save() async -> Item? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            validationError = .validation(.emptyField(AppStrings.title))
            return nil
        }
        guard trimmedTitle.count <= 80 else {
            validationError = .validation(.tooLong(field: AppStrings.title, max: 80))
            return nil
        }
        validationError = nil

        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .create:
                return try await repository.createItem(
                    title: trimmedTitle,
                    detail: detail,
                    priorityID: selectedPriorityID
                )
            case .edit(let item):
                return try await repository.updateItem(
                    Item(id: item.id, title: trimmedTitle, detail: detail, priorityID: selectedPriorityID)
                )
            }
        } catch {
            saveError = .from(error)
            return nil
        }
    }
}
