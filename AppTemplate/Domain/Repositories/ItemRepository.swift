import Foundation

/// Domain-facing contract. Presentation depends on this protocol, never on the concrete
/// Data-layer implementation — that's what lets ViewModels take either the real or mock
/// implementation with no other code changes.
protocol ItemRepository {
    func fetchItems() async throws -> [Item]
    func fetchItem(id: String) async throws -> Item?
    func createItem(title: String, detail: String) async throws -> Item
    func updateItem(_ item: Item) async throws -> Item
    func deleteItem(id: String) async throws
}
