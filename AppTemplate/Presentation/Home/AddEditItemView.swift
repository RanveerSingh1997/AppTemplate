import SwiftUI

struct AddEditItemView: View {
    @State private var viewModel: AddEditItemViewModel
    @Environment(\.dismiss) private var dismiss
    let onSaved: (Item) -> Void

    init(viewModel: AddEditItemViewModel, onSaved: @escaping (Item) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $viewModel.title)
                    TextField("Detail", text: $viewModel.detail, axis: .vertical)
                }
                Section("Priority") {
                    priorityPicker
                }
                if let message = viewModel.validationError?.errorDescription {
                    Text(message).foregroundStyle(.red)
                }
                if let message = viewModel.saveError?.errorDescription {
                    Text(message).foregroundStyle(.red)
                }
            }
            .disabled(viewModel.isSaving)
            .navigationTitle(viewModel.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                if let saved = await viewModel.save() {
                                    onSaved(saved)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
        }
        // Without this, swipe-to-dismiss bypasses the disabled Cancel button above and
        // closes the sheet while the save is still in flight.
        .interactiveDismissDisabled(viewModel.isSaving)
        // Independent of the item form's own state — a second, concurrently-loading
        // fetch on the same screen (see AddEditItemViewModel.priorityOptions).
        .task { await viewModel.loadPriorities() }
    }

    private var priorityPicker: some View {
        ViewStateView(state: viewModel.priorityOptions) { priorities in
            Picker("Priority", selection: $viewModel.selectedPriorityID) {
                Text("None").tag(String?.none)
                ForEach(priorities) { priority in
                    Text(priority.name).tag(Optional(priority.id))
                }
            }
        } failed: { message in
            Text(message).foregroundStyle(.secondary)
        }
    }
}

#Preview("Create") {
    AddEditItemView(
        viewModel: AddEditItemViewModel(
            mode: .create,
            repository: MockItemRepositoryImpl(),
            priorityRepository: MockPriorityRepositoryImpl()
        ),
        onSaved: { _ in }
    )
}

#Preview("Edit") {
    AddEditItemView(
        viewModel: AddEditItemViewModel(
            mode: .edit(MockItemRepositoryImpl.sampleItems[0]),
            repository: MockItemRepositoryImpl(),
            priorityRepository: MockPriorityRepositoryImpl()
        ),
        onSaved: { _ in }
    )
}
