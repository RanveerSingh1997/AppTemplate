import Foundation
import SwiftData

/// Network-first, cache-fallback: fetch DTOs from the API, mirror them into SwiftData via
/// `ItemMapper`, and map to the domain `Item` shape at the boundary. If the network call
/// fails, serve the last cached copy (also mapped to `Item`, filtered by `search` too)
/// instead of failing outright.
@MainActor
final class ItemRepositoryImpl: ItemRepository {
    private let apiClient: APIClient
    private let modelContext: ModelContext
    private let mapper: ItemMapper

    init(apiClient: APIClient, modelContext: ModelContext, mapper: ItemMapper = ItemMapper()) {
        self.apiClient = apiClient
        self.modelContext = modelContext
        self.mapper = mapper
    }

    func fetchItems(search: String?) async throws -> [Item] {
        do {
            let dtos: [ItemDTO] = try await apiClient.send(APIRequest(endpoint: .fetchItems(search: search)))
            upsert(dtos)
            pruneStale(against: dtos)
            return dtos.map(\.asDomain)
        } catch {
            let cached = try fetchCached(matching: search)
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
        upsert(dtos)
        return dtos.map(\.asDomain)
    }

    func fetchItem(id: String) async throws -> Item? {
        // Checked first, not just as a network fallback: `fetchItems()` only returns the
        // first page, so an item from a later page (already cached via `fetchMoreItems`'s
        // upsert) would otherwise look "not found".
        if let cached = try? modelContext.fetch(FetchDescriptor<CachedItem>()).first(where: { $0.id == id }) {
            return cached.asDomain
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
        _ = mapper.toEntity(dto: created, context: modelContext)
        return created.asDomain
    }

    func updateItem(_ item: Item) async throws -> Item {
        let updated: ItemDTO = try await apiClient.send(
            APIRequest(endpoint: .updateItem(id: item.id), json: item.asDTO)
        )
        if let existing = try? modelContext.fetch(FetchDescriptor<CachedItem>())
            .first(where: { $0.id == updated.id }) {
            _ = mapper.updateEntity(existing, with: updated, context: modelContext)
        } else {
            _ = mapper.toEntity(dto: updated, context: modelContext)
        }
        return updated.asDomain
    }

    func deleteItem(id: String) async throws {
        let _: EmptyResponse = try await apiClient.send(
            APIRequest(endpoint: .deleteItem(id: id))
        )
        if let existing = try? modelContext.fetch(FetchDescriptor<CachedItem>()).first(where: { $0.id == id }) {
            modelContext.delete(existing)
        }
    }

    /// Upserts fetched DTOs against existing cached entities (via the mapper), rather than a
    /// wholesale delete-and-reinsert. Never deletes — safe to call with a partial (paginated)
    /// set, unlike `pruneStale`.
    private func upsert(_ dtos: [ItemDTO]) {
        let existing = (try? modelContext.fetch(FetchDescriptor<CachedItem>())) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for dto in dtos {
            if let entity = existingByID[dto.id] {
                _ = mapper.updateEntity(entity, with: dto, context: modelContext)
            } else {
                _ = mapper.toEntity(dto: dto, context: modelContext)
            }
        }
    }

    /// Drops any cached row not present in `dtos`. Only safe when `dtos` is the *complete*
    /// current set (the unpaginated `fetchItems` call) — never call this with a single
    /// page's worth, or every other page's cached rows would look stale and get deleted.
    private func pruneStale(against dtos: [ItemDTO]) {
        let existing = (try? modelContext.fetch(FetchDescriptor<CachedItem>())) ?? []
        let staleIDs = Set(existing.map(\.id)).subtracting(dtos.map(\.id))
        for entity in existing where staleIDs.contains(entity.id) {
            modelContext.delete(entity)
        }
    }

    private func fetchCached(matching search: String?) throws -> [Item] {
        let items: [Item]
        do {
            items = try modelContext.fetch(FetchDescriptor<CachedItem>()).map(\.asDomain)
        } catch {
            throw AppError.persistence(.fetchFailed)
        }
        guard let search, !search.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }
}
