import Foundation

/// In-memory implementation used in development builds so the app runs immediately
/// with no backend/config required. Swap for `ItemRepositoryImpl` per environment in
/// `AppDependencies`, never by branching inside the repository itself.
final class MockItemRepositoryImpl: ItemRepository {
    /// How many items `fetchItems`/`fetchMoreItems` return per call — mirrors whatever page
    /// size a real backend would enforce server-side.
    static let pageSize = 10

    private var items: [Item]
    /// Zero by default (instant, for normal dev use). Tests that need to deterministically
    /// observe a ViewModel's mid-flight state (e.g. `ViewState.refreshing` before the fetch
    /// completes) set this instead of racing real task scheduling.
    private let artificialDelay: Duration
    /// Set in tests that need `deleteItem` to fail deterministically — nil (never throws)
    /// for normal dev use.
    private let deleteError: Error?

    init(
        items: [Item] = MockItemRepositoryImpl.sampleItems,
        artificialDelay: Duration = .zero,
        deleteError: Error? = nil
    ) {
        self.items = items
        self.artificialDelay = artificialDelay
        self.deleteError = deleteError
    }

    func fetchItems(search: String?) async throws -> [Item] {
        if artificialDelay > .zero {
            try? await Task.sleep(for: artificialDelay)
        }
        return Array(matching(search).prefix(Self.pageSize))
    }

    func fetchMoreItems(search: String?, offset: Int) async throws -> [Item] {
        if artificialDelay > .zero {
            try? await Task.sleep(for: artificialDelay)
        }
        let matches = matching(search)
        guard offset < matches.count else { return [] }
        return Array(matches[offset...].prefix(Self.pageSize))
    }

    private func matching(_ search: String?) -> [Item] {
        guard let search, !search.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    func fetchItem(id: String) async throws -> Item? {
        items.first { $0.id == id }
    }

    func createItem(title: String, detail: String, priorityID: String?) async throws -> Item {
        let item = Item(id: UUID().uuidString, title: title, detail: detail, priorityID: priorityID)
        // Inserted at the front, not appended — `fetchItems` now returns only the first
        // page, so a newly created item needs to land there to show up in the list right
        // after `HomeSplitView` reloads, instead of being pushed onto a later page.
        items.insert(item, at: 0)
        return item
    }

    func updateItem(_ item: Item) async throws -> Item {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            throw AppError.persistence(.notFound)
        }
        items[index] = item
        return item
    }

    func deleteItem(id: String) async throws {
        if artificialDelay > .zero {
            try? await Task.sleep(for: artificialDelay)
        }
        if let deleteError { throw deleteError }
        items.removeAll { $0.id == id }
    }

    // 25 items against a page size of 10 — enough for `HomeSplitView`'s load-more to fire
    // more than once, so pagination is actually visible when running the Dev build.
    static let sampleItems: [Item] = [
        Item(id: "1", title: "First Item", detail: "Replace this with your real data."),
        Item(id: "2", title: "Second Item", detail: "Wire ItemRepositoryImpl to your real API in AppDependencies."),
        Item(id: "3", title: "Third Item", detail: "See README.md for how to add a new feature module.")
    ] + (4...25).map { Item(id: "\($0)", title: "Item \($0)", detail: "Sample item for pagination demo.") }
}
