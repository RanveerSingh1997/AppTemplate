import Foundation
import SwiftData

/// Generic CRUD against any SwiftData `@Model` type — what `SwiftDataItemCache` (and any
/// future SwiftData-backed cache) builds on instead of each repeating its own
/// `modelContext.fetch(FetchDescriptor<Entity>())` boilerplate. Parameterized once per
/// entity at construction (`SwiftDataStore<CachedItem>(modelContext:)`), not per call.
@MainActor
struct SwiftDataStore<Entity: PersistentModel> {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Defaults to fetching everything — pass a `FetchDescriptor` with a `predicate`/
    /// `sortBy`/`fetchLimit` to push filtering down to SwiftData instead of fetching
    /// everything and filtering in Swift (see `SwiftDataItemCache.fetchByID`/`delete`,
    /// which query by `CachedItem`'s unique `id` this way instead of a full scan).
    func fetch(_ descriptor: FetchDescriptor<Entity> = FetchDescriptor<Entity>()) throws -> [Entity] {
        try modelContext.fetch(descriptor)
    }

    func insert(_ entity: Entity) {
        modelContext.insert(entity)
    }

    func delete(_ entity: Entity) {
        modelContext.delete(entity)
    }
}
