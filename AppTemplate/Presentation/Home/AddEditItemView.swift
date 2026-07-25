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
                if let message = viewModel.validationError?.errorDescription {
                    Text(message).foregroundStyle(.red)
                }
                if let message = viewModel.saveError?.errorDescription {
                    Text(message).foregroundStyle(.red)
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if let saved = await viewModel.save() {
                                onSaved(saved)
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }
}
