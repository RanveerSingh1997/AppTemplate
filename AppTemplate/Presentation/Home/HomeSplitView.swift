import SwiftUI

/// NavigationSplitView is natively adaptive: a two-column sidebar+detail layout on
/// iPad/Mac, a single push-style column on iPhone — no manual size-class branching.
struct HomeSplitView: View {
    @State private var viewModel: HomeViewModel
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
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
        self.makeDetailViewModel = makeDetailViewModel
        self.makeFormViewModel = makeFormViewModel
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Items")
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
            ContentUnavailableView(
                "Couldn't Load Items",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .loaded(let items):
            List(items, selection: $coordinator.selectedItemID) { item in
                Text(item.title)
                    .tag(item.id)
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
                    }
            }
        }
    }
}
