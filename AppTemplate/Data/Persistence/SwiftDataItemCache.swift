import Foundation
import SwiftData

/// The only place SwiftData is used for item persistence — `ItemRepositoryImpl` only ever
/// sees this through the `ItemCache` protocol, never `ModelContext`/`CachedItem` directly.
/// `modelContext` itself only ever appears in `init` — every method body works through
/// `store` (`SwiftDataStore<CachedItem>`) instead.
@MainActor
struct SwiftDataItemCache: ItemCache {
    private let store: SwiftDataStore<CachedItem>
    private let mapper: ItemMapper

    init(modelContext: ModelContext, mapper: ItemMapper = ItemMapper()) {
        store = SwiftDataStore(modelContext: modelContext)
        self.mapper = mapper
    }

    func upsert(_ dtos: [ItemDTO]) {
        // createItem/updateItem upsert exactly one DTO — a single predicate-based lookup
        // (like fetchByID/delete use) beats fetching every cached row for a one-row check.
        guard dtos.count > 1 else {
            if let dto = dtos.first {
                upsertOne(dto)
            }
            return
        }
        // fetchItems/fetchMoreItems upsert a whole page at once — here, one bulk fetch +
        // an in-memory dictionary lookup beats issuing a separate predicate query per DTO.
        let existing = (try? store.fetch()) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for dto in dtos {
            if let entity = existingByID[dto.id] {
                _ = mapper.updateEntity(entity, with: dto)
            } else {
                _ = mapper.toEntity(dto: dto, store: store)
            }
        }
    }

    private func upsertOne(_ dto: ItemDTO) {
        if let entity = try? store.first(withID: dto.id) {
            _ = mapper.updateEntity(entity, with: dto)
        } else {
            _ = mapper.toEntity(dto: dto, store: store)
        }
    }

    func pruneStale(against dtos: [ItemDTO]) {
        let existing = (try? store.fetch()) ?? []
        let staleIDs = Set(existing.map(\.id)).subtracting(dtos.map(\.id))
        for entity in existing where staleIDs.contains(entity.id) {
            store.delete(entity)
        }
    }

    func fetchAll(matching search: String?) throws -> [Item] {
        let items: [Item]
        do {
            items = try store.fetch().map(\.asDomain)
        } catch {
            throw AppError.persistence(.fetchFailed)
        }
        guard let search, !search.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    func fetchByID(_ id: String) -> Item? {
        let match = try? store.first(withID: id)
        return match?.asDomain
    }

    func delete(id: String) {
        if let existing = try? store.first(withID: id) {
            store.delete(existing)
        }
    }
}
