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
    /// everything and filtering in Swift. `first(withID:)` below is the common case;
    /// build a custom `FetchDescriptor` directly for anything else.
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

/// `Entity.ID: Codable & Sendable` (not just `Identifiable`'s own `ID: Hashable`) because
/// `#Predicate`'s macro expansion needs the compared value's type to satisfy
/// `StandardPredicateExpression` machinery that requires `Codable` — without it, the
/// predicate below fails to compile with a cryptic "cannot convert ... to closure result
/// type 'any StandardPredicateExpression<Bool>'" pointing at the macro expansion, not this
/// line. `CachedItem.id: String` already satisfies both.
extension SwiftDataStore where Entity: Identifiable, Entity.ID: Codable & Sendable {
    /// Queries by `id` directly (a `FetchDescriptor` predicate + `fetchLimit`) instead of
    /// fetching every row and scanning for a match in Swift — the generic version of what
    /// `SwiftDataItemCache.fetchByID`/`delete` used to build by hand for `CachedItem`
    /// specifically. Available on any `Entity` that's `Identifiable` (`CachedItem` is).
    func first(withID id: Entity.ID) throws -> Entity? {
        var descriptor = FetchDescriptor<Entity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }
}
