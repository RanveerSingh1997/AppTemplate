import Foundation

/// The persistence seam `ItemRepositoryImpl` depends on instead of talking to SwiftData
/// directly. Speaks only in `ItemDTO`/`Item`/`String` — never a SwiftData type — so
/// swapping persistence tech (Core Data, SQLite, a flat file, ...) later means writing one
/// new conformance (`SwiftDataItemCache` is the only place SwiftData is used for item
/// persistence) and changing one line in `AppDependencies`; none of `ItemRepositoryImpl`'s
/// network/cache-fallback/pagination-safety logic has to change.
@MainActor
protocol ItemCache {
    /// Upserts fetched DTOs against whatever's cached, without deleting anything — safe to
    /// call with a partial (paginated) set. See `ItemRepositoryImpl.fetchMoreItems`.
    func upsert(_ dtos: [ItemDTO])

    /// Drops any cached row not present in `dtos`. Only safe when `dtos` is the *complete*
    /// current set (an unpaginated `fetchItems` call) — never call this with a single
    /// page's worth, or every other page's cached rows would look stale and get dropped.
    func pruneStale(against dtos: [ItemDTO])

    func fetchAll(matching search: String?) throws -> [Item]
    func fetchByID(_ id: String) -> Item?
    func delete(id: String)
}
