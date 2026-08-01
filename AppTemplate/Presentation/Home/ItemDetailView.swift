import SwiftUI

struct ItemDetailView: View {
    @State private var viewModel: ItemDetailViewModel
    private let coordinator: NavigationCoordinator

    init(viewModel: ItemDetailViewModel, coordinator: NavigationCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        ViewStateView(state: viewModel.state, failureTitle: AppStrings.couldntLoadItem) { item in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
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
                        Label(AppStrings.edit, systemImage: "pencil")
                    }
                }
            }
        }
        .task { await viewModel.load() }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(
            viewModel: ItemDetailViewModel(itemID: "1", repository: MockItemRepositoryImpl()),
            coordinator: NavigationCoordinator()
        )
    }
}
