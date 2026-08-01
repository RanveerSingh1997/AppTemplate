import Foundation

/// Network-first, cache-fallback: fetch DTOs from the API, upsert them into `cache`, and
/// map to the domain `Item` shape at the boundary. If the network call fails, serve the
/// last cached copy (also filtered by `search`) instead of failing outright. No persistence
/// framework's types appear here at all — see `ItemCache`'s doc comment for why.
@MainActor
final class ItemRepositoryImpl: ItemRepository {
    private let apiClient: APIClient
    private let cache: ItemCache

    init(apiClient: APIClient, cache: ItemCache) {
        self.apiClient = apiClient
        self.cache = cache
    }

    func fetchItems(search: String?) async throws -> [Item] {
        do {
            let dtos: [ItemDTO] = try await apiClient.send(APIRequest(endpoint: .fetchItems(search: search)))
            cache.upsert(dtos)
            cache.pruneStale(against: dtos)
            return dtos.map(\.asDomain)
        } catch {
            let cached = try cache.fetchAll(matching: search)
            guard !cached.isEmpty else { throw error }
            return cached
        }
    }

    // ponytail: no cache fallback here (unlike `fetchItems`) — a failed load-more just
    // propagates the error, since there's no meaningful "cached page 2" to fall back to.
    func fetchMoreItems(search: String?, offset: Int) async throws -> [Item] {
        let dtos: [ItemDTO] = try await apiClient.send(
            APIRequest(endpoint: .fetchItems(search: search, offset: offset))
        )
        // Upsert only — never prune. A page fetch's DTOs are a subset of the whole list, so
        // treating anything outside it as "stale" would delete other pages' cached rows.
        cache.upsert(dtos)
        return dtos.map(\.asDomain)
    }

    func fetchItem(id: String) async throws -> Item? {
        // Checked first, not just as a network fallback: `fetchItems()` only returns the
        // first page, so an item from a later page (already cached via `fetchMoreItems`'s
        // upsert) would otherwise look "not found".
        if let cached = cache.fetchByID(id) {
            return cached
        }
        return try await fetchItems().first { $0.id == id }
    }

    func createItem(title: String, detail: String, priorityID: String?) async throws -> Item {
        // The server assigns the real id and returns it in the response; the outgoing
        // `id` is a placeholder the server is expected to ignore.
        let payload = ItemDTO(id: "", name: title, description: detail, priorityID: priorityID)
        let created: ItemDTO = try await apiClient.send(
            APIRequest(endpoint: .createItem, json: payload)
        )
        cache.upsert([created])
        return created.asDomain
    }

    func updateItem(_ item: Item) async throws -> Item {
        let updated: ItemDTO = try await apiClient.send(
            APIRequest(endpoint: .updateItem(id: item.id), json: item.asDTO)
        )
        cache.upsert([updated])
        return updated.asDomain
    }

    func deleteItem(id: String) async throws {
        let _: EmptyResponse = try await apiClient.send(
            APIRequest(endpoint: .deleteItem(id: id))
        )
        cache.delete(id: id)
    }
}
