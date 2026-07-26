@testable import AppTemplate
import Testing

struct MockItemRepositoryImplTests {
    @Test
    func fetchItemReturnsMatchingItem() async throws {
        let repository = MockItemRepositoryImpl()
        let item = try await repository.fetchItem(id: "1")
        #expect(item?.title == "First Item")
    }

    @Test
    func fetchItemReturnsNilForUnknownID() async throws {
        let repository = MockItemRepositoryImpl()
        let item = try await repository.fetchItem(id: "missing")
        #expect(item == nil)
    }

    @Test
    func createItemAddsToFetchedItems() async throws {
        let repository = MockItemRepositoryImpl()
        let created = try await repository.createItem(title: "New", detail: "Detail")
        let all = try await repository.fetchItems()
        #expect(all.contains { $0.id == created.id })
    }

    @Test
    func updateItemChangesFetchedValue() async throws {
        let repository = MockItemRepositoryImpl()
        let updated = try await repository.updateItem(Item(id: "1", title: "Renamed", detail: "New detail"))
        #expect(updated.title == "Renamed")
        let fetched = try await repository.fetchItem(id: "1")
        #expect(fetched?.title == "Renamed")
    }

    @Test
    func updateItemThrowsForUnknownID() async throws {
        let repository = MockItemRepositoryImpl()
        await #expect(throws: AppError.self) {
            _ = try await repository.updateItem(Item(id: "missing", title: "x", detail: "y"))
        }
    }

    @Test
    func deleteItemRemovesFromFetchedItems() async throws {
        let repository = MockItemRepositoryImpl()
        try await repository.deleteItem(id: "1")
        let fetched = try await repository.fetchItem(id: "1")
        #expect(fetched == nil)
    }

    @Test
    func fetchItemsFiltersBySearchTerm() async throws {
        let repository = MockItemRepositoryImpl()
        let results = try await repository.fetchItems(search: "second")
        #expect(results.map(\.title) == ["Second Item"])
    }

    @Test
    func fetchItemsWithNilSearchReturnsEverything() async throws {
        let repository = MockItemRepositoryImpl()
        let results = try await repository.fetchItems(search: nil)
        #expect(results.count == MockItemRepositoryImpl.sampleItems.count)
    }
}
