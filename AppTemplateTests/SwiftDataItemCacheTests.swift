@testable import AppTemplate
import SwiftData
import Testing

/// Exercises `SwiftDataItemCache` against a real (in-memory) `ModelContainer` — unlike
/// `ItemRepositoryImplTests`' fake `InMemoryItemCache`, this is what actually proves
/// `SwiftDataStore.fetch(_:)`'s predicate-based `fetchByID`/`delete` work against real
/// SwiftData, not just against a hand-written dictionary.
@MainActor
struct SwiftDataItemCacheTests {
    private func makeCache() throws -> SwiftDataItemCache {
        let container = try ModelContainer(
            for: CachedItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataItemCache(modelContext: ModelContext(container))
    }

    private func makeDTO(_ id: String, title: String = "Item") -> ItemDTO {
        ItemDTO(id: id, name: title, description: "Detail", priorityID: nil)
    }

    @Test
    func upsertThenFetchAllReturnsInsertedItems() throws {
        let cache = try makeCache()
        cache.upsert([makeDTO("1", title: "First"), makeDTO("2", title: "Second")])

        let items = try cache.fetchAll(matching: nil)

        #expect(Set(items.map(\.id)) == ["1", "2"])
    }

    @Test
    func upsertUpdatesAnExistingRowInPlaceInsteadOfDuplicatingIt() throws {
        let cache = try makeCache()
        cache.upsert([makeDTO("1", title: "Original")])

        cache.upsert([makeDTO("1", title: "Renamed")])

        let items = try cache.fetchAll(matching: nil)
        #expect(items.count == 1)
        #expect(items.first?.title == "Renamed")
    }

    @Test
    func fetchByIDFindsTheMatchingRowByItsUniquePredicate() throws {
        let cache = try makeCache()
        cache.upsert([makeDTO("1", title: "First"), makeDTO("2", title: "Second")])

        #expect(cache.fetchByID("2")?.title == "Second")
    }

    @Test
    func fetchByIDReturnsNilForAnUnknownID() throws {
        let cache = try makeCache()
        #expect(cache.fetchByID("missing") == nil)
    }

    @Test
    func deleteRemovesOnlyTheMatchingRow() throws {
        let cache = try makeCache()
        cache.upsert([makeDTO("1"), makeDTO("2")])

        cache.delete(id: "1")

        #expect(cache.fetchByID("1") == nil)
        #expect(cache.fetchByID("2") != nil)
    }

    @Test
    func pruneStaleDropsRowsNotInTheGivenDTOsButKeepsTheRest() throws {
        let cache = try makeCache()
        cache.upsert([makeDTO("1"), makeDTO("2")])

        cache.pruneStale(against: [makeDTO("2")])

        let items = try cache.fetchAll(matching: nil)
        #expect(items.map(\.id) == ["2"])
    }
}
