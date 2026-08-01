@testable import AppTemplate
import Testing

/// Returns whatever `sendResult` holds for every `send<T>` call, regardless of `T` — good
/// enough for `ItemRepositoryImpl`, which never has two differently-typed `send` calls in
/// flight at once.
@MainActor
private final class StubAPIClient: APIClient {
    var sendResult: Result<Any, Error> = .success(())

    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        switch sendResult {
        case .success(let value):
            guard let typed = value as? T else {
                fatalError("StubAPIClient: expected \(T.self), got \(type(of: value))")
            }
            return typed
        case .failure(let error):
            throw error
        }
    }

    func upload(_ request: APIRequest, file: FileUploadDescriptor) -> AsyncStream<UploadEvent> {
        AsyncStream { $0.finish() }
    }
}

/// `ItemCache` conformance backed by a plain dictionary — proves `ItemRepositoryImpl`
/// really only depends on the `ItemCache` protocol, not SwiftData, and is what makes these
/// tests possible without spinning up a `ModelContainer`.
@MainActor
private final class InMemoryItemCache: ItemCache {
    private(set) var dtosByID: [String: ItemDTO] = [:]
    private(set) var pruneStaleCallCount = 0

    func upsert(_ dtos: [ItemDTO]) {
        for dto in dtos { dtosByID[dto.id] = dto }
    }

    func pruneStale(against dtos: [ItemDTO]) {
        pruneStaleCallCount += 1
        let keep = Set(dtos.map(\.id))
        dtosByID = dtosByID.filter { keep.contains($0.key) }
    }

    func fetchAll(matching search: String?) throws -> [Item] {
        let all = dtosByID.values.map(\.asDomain)
        guard let search, !search.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    func fetchByID(_ id: String) -> Item? {
        dtosByID[id]?.asDomain
    }

    func delete(id: String) {
        dtosByID[id] = nil
    }
}

@MainActor
struct ItemRepositoryImplTests {
    private func makeItem(_ id: String, title: String = "Item") -> ItemDTO {
        ItemDTO(id: id, name: title, description: "Detail", priorityID: nil)
    }

    @Test
    func fetchItemsUpsertsAndPrunesTheCacheFromANetworkSuccess() async throws {
        let client = StubAPIClient()
        let cache = InMemoryItemCache()
        cache.upsert([makeItem("stale")]) // present before the fetch, absent from its result
        client.sendResult = .success([makeItem("1", title: "First")])
        let repository = ItemRepositoryImpl(apiClient: client, cache: cache)

        let items = try await repository.fetchItems(search: nil)

        #expect(items.map(\.id) == ["1"])
        #expect(cache.dtosByID["stale"] == nil) // pruned
        #expect(cache.pruneStaleCallCount == 1)
    }

    @Test
    func fetchItemsFallsBackToTheCacheOnNetworkFailure() async throws {
        let client = StubAPIClient()
        let cache = InMemoryItemCache()
        cache.upsert([makeItem("1", title: "Cached Item")])
        client.sendResult = .failure(AppError.network(.noConnection))
        let repository = ItemRepositoryImpl(apiClient: client, cache: cache)

        let items = try await repository.fetchItems(search: nil)

        #expect(items.map(\.id) == ["1"])
    }

    @Test
    func fetchItemsRethrowsTheNetworkErrorWhenTheCacheIsAlsoEmpty() async {
        let client = StubAPIClient()
        client.sendResult = .failure(AppError.network(.noConnection))
        let repository = ItemRepositoryImpl(apiClient: client, cache: InMemoryItemCache())

        await #expect(throws: AppError.self) {
            _ = try await repository.fetchItems(search: nil)
        }
    }

    @Test
    func fetchMoreItemsUpsertsWithoutPruningEarlierPages() async throws {
        let client = StubAPIClient()
        let cache = InMemoryItemCache()
        cache.upsert([makeItem("1", title: "Page 1 Item")]) // simulates an earlier fetchItems()
        client.sendResult = .success([makeItem("2", title: "Page 2 Item")])
        let repository = ItemRepositoryImpl(apiClient: client, cache: cache)

        let page2 = try await repository.fetchMoreItems(search: nil, offset: 1)

        #expect(page2.map(\.id) == ["2"])
        #expect(cache.dtosByID["1"] != nil) // page 1's row must survive
        #expect(cache.pruneStaleCallCount == 0)
    }

    @Test
    func fetchItemFindsAnItemCachedByAnEarlierPageEvenThoughFetchItemsOnlyCoversPageOne() async throws {
        let client = StubAPIClient()
        let cache = InMemoryItemCache()
        cache.upsert([makeItem("42", title: "Second Page Item")])
        // fetchItems() (the fallback fetchItem would otherwise use) won't include "42" —
        // proves the cache-first check, not the network fallback, is what finds it.
        client.sendResult = .success([makeItem("1", title: "First Page Item")])
        let repository = ItemRepositoryImpl(apiClient: client, cache: cache)

        let found = try await repository.fetchItem(id: "42")

        #expect(found?.title == "Second Page Item")
    }

    @Test
    func createItemUpsertsTheServerAssignedItemIntoTheCache() async throws {
        let client = StubAPIClient()
        client.sendResult = .success(makeItem("server-1", title: "New Item"))
        let cache = InMemoryItemCache()
        let repository = ItemRepositoryImpl(apiClient: client, cache: cache)

        let created = try await repository.createItem(title: "New Item", detail: "Detail", priorityID: nil)

        #expect(created.id == "server-1")
        #expect(cache.dtosByID["server-1"] != nil)
    }

    @Test
    func deleteItemRemovesItFromTheCache() async throws {
        let client = StubAPIClient()
        client.sendResult = .success(EmptyResponse())
        let cache = InMemoryItemCache()
        cache.upsert([makeItem("1")])
        let repository = ItemRepositoryImpl(apiClient: client, cache: cache)

        try await repository.deleteItem(id: "1")

        #expect(cache.dtosByID["1"] == nil)
    }
}
