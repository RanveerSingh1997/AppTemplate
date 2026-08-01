import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var state: ViewState<HomeScreenData> = .loading

    /// Bound to `.searchable(text:)`. Debounced via `searchTextDidChange()` — the View calls
    /// that on every keystroke; this property itself is just the current text.
    var searchText: String = ""

    /// Items currently mid-delete. The View disables that row (selection and swipe) while
    /// its id is in here, instead of leaving the whole list interactive during the network
    /// call — tapping into a detail screen for an item that's being deleted underneath you,
    /// or swiping the same row twice, are both states worth preventing rather than handling.
    private(set) var deletingItemIDs: Set<String> = []

    private let repository: ItemRepository
    private let priorityRepository: PriorityRepository
    private let alertService: AlertService
    private var searchDebounceTask: Task<Void, Never>?

    init(repository: ItemRepository, priorityRepository: PriorityRepository, alertService: AlertService) {
        self.repository = repository
        self.priorityRepository = priorityRepository
        self.alertService = alertService
    }

    func load() async {
        // Keep whatever's already on screen visible (as `.refreshing`) if this is a
        // re-fetch — e.g. a search term changing — rather than blanking to `.loading`.
        // Only the true first load, with nothing yet to show, uses `.loading`.
        state = state.value.map(ViewState.refreshing) ?? .loading
        do {
            let search = searchText.isEmpty ? nil : searchText
            // Both fetches start concurrently; `async let` cancels whichever hasn't
            // finished if the other throws, so no orphaned request on failure.
            // ponytail: re-fetches priorities on every reload, including every debounced
            // search, even though priority lookup data rarely changes. Fine while it's
            // cheap; cache it separately (fetch once, reuse across reloads) if that
            // ever measurably matters.
            async let items = repository.fetchItems(search: search)
            async let priorities = priorityRepository.fetchPriorities()
            state = .loaded(HomeScreenData(items: try await items, priorities: try await priorities))
        } catch {
            // `error.localizedDescription` already surfaces `AppError.errorDescription`
            // (via `LocalizedError` bridging) for our own errors, and a reasonable system
            // message for anything else — no `as AppError` branch needed to get that.
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
        } catch {
            // An alert, not `state = .failed(...)` — the rest of the list loaded fine;
            // only this one row's delete failed, so it should stay on screen underneath
            // the alert instead of the whole list blanking to `LoadFailureView`.
            alertService.showAlert(title: AppStrings.couldntDeleteItem, message: error.localizedDescription)
        }
    }
}
