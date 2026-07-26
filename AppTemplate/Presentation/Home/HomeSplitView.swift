import SwiftUI

/// NavigationSplitView is natively adaptive: a two-column sidebar+detail layout on
/// iPad/Mac, a single push-style column on iPhone — no manual size-class branching.
struct HomeSplitView: View {
    @Bindable private var viewModel: HomeViewModel
    @Bindable private var coordinator: NavigationCoordinator
    private let makeDetailViewModel: (String) -> ItemDetailViewModel
    private let makeFormViewModel: (ItemFormRoute) -> AddEditItemViewModel

    // Bumped whenever a save completes so the detail column — whose ItemDetailViewModel
    // is otherwise kept alive by SwiftUI as long as `selectedItemID` doesn't change — is
    // forced to rebuild and refetch instead of showing what's now stale data after an edit.
    @State private var detailRefreshToken = 0

    init(
        viewModel: HomeViewModel,
        coordinator: NavigationCoordinator,
        makeDetailViewModel: @escaping (String) -> ItemDetailViewModel,
        makeFormViewModel: @escaping (ItemFormRoute) -> AddEditItemViewModel
    ) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        self.makeDetailViewModel = makeDetailViewModel
        self.makeFormViewModel = makeFormViewModel
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Items")
                .searchable(text: $viewModel.searchText, prompt: "Search items")
                .onChange(of: viewModel.searchText) { _, _ in
                    viewModel.searchTextDidChange()
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            coordinator.presentItemForm(.create)
                        } label: {
                            Label("Add Item", systemImage: "plus")
                        }
                    }
                }
                .task { await viewModel.load() }
        } detail: {
            if let id = coordinator.selectedItemID {
                ItemDetailView(
                    viewModel: makeDetailViewModel(id),
                    coordinator: coordinator
                )
                .id("\(id)-\(detailRefreshToken)")
            } else {
                ContentUnavailableView("Select an Item", systemImage: "sidebar.left")
            }
        }
        .sheet(item: $coordinator.presentedItemForm) { route in
            AddEditItemView(viewModel: makeFormViewModel(route)) { _ in
                Task {
                    await viewModel.load()
                    detailRefreshToken += 1
                }
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
        case .failed(let message):
            LoadFailureView(title: "Couldn't Load Items", message: message)
        case .loaded(let data), .refreshing(let data):
            // Same list for both — `.refreshing` keeps the previous items on screen while a
            // new fetch is in flight (search, delete-then-reload) instead of blanking to a
            // spinner; the toolbar's ProgressView (below) is the only visible difference.
            if data.items.isEmpty {
                emptyState
            } else {
                itemList(data)
            }
        }
    }

    /// A search yielding zero results and a genuinely empty list are different situations —
    /// this is the concrete case the README's "separate flags per ViewModel" guidance is
    /// about: the *reason* for what's on screen lives on `HomeViewModel` (`searchText`),
    /// not on `ViewState`, which only knows "loaded, and it's empty."
    @ViewBuilder
    private var emptyState: some View {
        if viewModel.searchText.isEmpty {
            ContentUnavailableView("No Items", systemImage: "tray")
        } else {
            ContentUnavailableView.search(text: viewModel.searchText)
        }
    }

    private func itemList(_ data: HomeScreenData) -> some View {
        List(data.items, selection: $coordinator.selectedItemID) { item in
            let isDeleting = viewModel.deletingItemIDs.contains(item.id)
            HStack {
                VStack(alignment: .leading) {
                    Text(item.title)
                    if let priorityName = data.priorityName(for: item) {
                        Text(priorityName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if isDeleting {
                    Spacer()
                    ProgressView()
                }
            }
            .tag(item.id)
            // Blocks selection (navigating into the detail screen) and re-swiping this row
            // while its own delete is in flight — the rest of the list stays interactive.
            .disabled(isDeleting)
            .swipeActions {
                Button(role: .destructive) {
                    Task {
                        await viewModel.delete(id: item.id)
                        if coordinator.selectedItemID == item.id {
                            coordinator.selectItem(nil)
                        }
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(isDeleting)
            }
        }
        .toolbar {
            if case .refreshing = viewModel.state {
                ToolbarItem(placement: .status) {
                    ProgressView()
                }
            }
        }
    }
}
