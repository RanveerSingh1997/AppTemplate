import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var state: ViewState<[Item]> = .loading
    private let repository: ItemRepository

    init(repository: ItemRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await repository.fetchItems())
        } catch let error as AppError {
            state = .failed(error.errorDescription ?? "Something went wrong.")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func delete(id: String) async {
        do {
            try await repository.deleteItem(id: id)
            await load()
        } catch let error as AppError {
            state = .failed(error.errorDescription ?? "Something went wrong.")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
