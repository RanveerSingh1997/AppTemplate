import Observation

@Observable
@MainActor
final class AddEditItemViewModel {
    enum Mode: Equatable {
        case create
        case edit(Item)
    }

    var title: String
    var detail: String
    private(set) var validationError: AppError?
    private(set) var saveError: AppError?
    private(set) var isSaving = false

    private let mode: Mode
    private let repository: ItemRepository

    init(mode: Mode, repository: ItemRepository) {
        self.mode = mode
        self.repository = repository
        switch mode {
        case .create:
            title = ""
            detail = ""
        case .edit(let item):
            title = item.title
            detail = item.detail
        }
    }

    var navigationTitle: String {
        switch mode {
        case .create: return "New Item"
        case .edit: return "Edit Item"
        }
    }

    /// Returns the saved item on success, or `nil` if validation/save failed —
    /// check `validationError`/`saveError` for what to show.
    func save() async -> Item? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            validationError = .validation(.emptyField("Title"))
            return nil
        }
        guard trimmedTitle.count <= 80 else {
            validationError = .validation(.tooLong(field: "Title", max: 80))
            return nil
        }
        validationError = nil

        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .create:
                return try await repository.createItem(title: trimmedTitle, detail: detail)
            case .edit(let item):
                return try await repository.updateItem(Item(id: item.id, title: trimmedTitle, detail: detail))
            }
        } catch let error as AppError {
            saveError = error
            return nil
        } catch {
            saveError = .unknown(error.localizedDescription)
            return nil
        }
    }
}
