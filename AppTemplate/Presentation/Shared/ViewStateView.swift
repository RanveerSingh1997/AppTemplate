import SwiftUI

/// The `switch state { case .loading: ... case .failed: ... case .loaded/.refreshing: ... }`
/// every `ViewState<Value>` consumer was writing by hand — `HomeSplitView`'s sidebar,
/// `ItemDetailView`'s body, and `AddEditItemView`'s `priorityPicker` all had their own copy,
/// identical in the `.loading`/`.loaded`/`.refreshing` arms and differing only in what
/// `.failed` renders (a full-screen `LoadFailureView` for the two screen-level cases, a
/// plain secondary-style `Text` for the inline picker). One generic view, one place to
/// change if the loading spinner ever needs to become something else.
struct ViewStateView<Value, Loaded: View, Failed: View>: View {
    let state: ViewState<Value>
    @ViewBuilder let loaded: (Value) -> Loaded
    @ViewBuilder let failed: (String) -> Failed

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
        case .failed(let message):
            failed(message)
        case .loaded(let value), .refreshing(let value):
            loaded(value)
        }
    }
}

extension ViewStateView where Failed == LoadFailureView {
    /// The common case — a full-screen `LoadFailureView` for `.failed`. Use the base
    /// initializer directly (with an explicit `failed:` builder) for an inline failure
    /// presentation instead, as `AddEditItemView.priorityPicker` does.
    init(
        state: ViewState<Value>,
        failureTitle: String,
        @ViewBuilder loaded: @escaping (Value) -> Loaded
    ) {
        self.init(state: state, loaded: loaded) { message in
            LoadFailureView(title: failureTitle, message: message)
        }
    }
}
