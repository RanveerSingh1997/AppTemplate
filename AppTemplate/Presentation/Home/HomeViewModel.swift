import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var state: ViewState<[Item]> = .loading

    /// Bound to `.searchable(text:)`. Debounced via `searchTextDidChange()` — the View calls
    /// that on every keystroke; this property itself is just the current text.
    var searchText: String = ""

    /// Items currently mid-delete. The View disables that row (selection and swipe) while
    /// its id is in here, instead of leaving the whole list interactive during the network
    /// call — tapping into a detail screen for an item that's being deleted underneath you,
    /// or swiping the same row twice, are both states worth preventing rather than handling.
    private(set) var deletingItemIDs: Set<String> = []

    private let repository: ItemRepository
    private var searchDebounceTask: Task<Void, Never>?

    init(repository: ItemRepository) {
        self.repository = repository
    }

    func load() async {
        // Keep whatever's already on screen visible (as `.refreshing`) if this is a
        // re-fetch — e.g. a search term changing — rather than blanking to `.loading`.
        // Only the true first load, with nothing yet to show, uses `.loading`.
        state = state.value.map(ViewState.refreshing) ?? .loading
        do {
            let search = searchText.isEmpty ? nil : searchText
            state = .loaded(try await repository.fetchItems(search: search))
        } catch let error as AppError {
            state = .failed(error.errorDescription ?? "Something went wrong.")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Call on every `searchText` change (e.g. from `.onChange(of:)`). Cancels any pending
    /// search-triggered reload and schedules a new one — avoids firing a request per
    /// keystroke while the user is still typing.
    func searchTextDidChange() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    func delete(id: String) async {
        guard !deletingItemIDs.contains(id) else { return }
        deletingItemIDs.insert(id)
        defer { deletingItemIDs.remove(id) }

        do {
            try await repository.deleteItem(id: id)
            await load()
        } catch let error as AppError {
            state = .failed(error.errorDescription ?? "Something went wrong.")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
