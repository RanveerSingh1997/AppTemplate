import SwiftUI

struct ItemDetailView: View {
    @State private var viewModel: ItemDetailViewModel
    private let coordinator: NavigationCoordinator

    init(viewModel: ItemDetailViewModel, coordinator: NavigationCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadFailureView(title: "Couldn't Load Item", message: message)
            case .loaded(let item), .refreshing(let item):
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.title).font(.title.bold())
                        Text(item.detail).font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .navigationTitle(item.title)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            coordinator.presentItemForm(.edit(item))
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                }
            }
        }
        .task { await viewModel.load() }
    }
}
