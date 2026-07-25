import Observation

@Observable
@MainActor
final class ItemDetailViewModel {
    enum State {
        case loading
        case loaded(Item)
        case failed(String)
    }

    private(set) var state: State = .loading
    private let itemID: String
    private let repository: ItemRepository

    init(itemID: String, repository: ItemRepository) {
        self.itemID = itemID
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            guard let item = try await repository.fetchItem(id: itemID) else {
                state = .failed("Item not found.")
                return
            }
            state = .loaded(item)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
