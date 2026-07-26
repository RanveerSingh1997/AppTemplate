import Foundation

/// Domain-facing contract. Presentation depends on this protocol, never on the concrete
/// Data-layer implementation — that's what lets ViewModels take either the real or mock
/// implementation with no other code changes.
protocol ItemRepository {
    /// `search` is threaded all the way to `APIEndpoint.items(search:)`'s query parameter
    /// (and used to filter the cache-fallback path) — see `ItemRepositoryImpl`.
    func fetchItems(search: String?) async throws -> [Item]
    func fetchItem(id: String) async throws -> Item?
    func createItem(title: String, detail: String, priorityID: String?) async throws -> Item
    func updateItem(_ item: Item) async throws -> Item
    func deleteItem(id: String) async throws
}

extension ItemRepository {
    /// Convenience for the common no-filter case, so existing call sites don't need
    /// `search: nil` at every use.
    func fetchItems() async throws -> [Item] {
        try await fetchItems(search: nil)
    }

    /// Convenience for callers that don't need to set a priority.
    func createItem(title: String, detail: String) async throws -> Item {
        try await createItem(title: title, detail: detail, priorityID: nil)
    }
}
