import Foundation

/// Standard shape for any "fetch a resource, then show it" screen. Every such ViewModel
/// (`HomeViewModel`, `ItemDetailViewModel`, ...) declares `state: ViewState<Value>` instead
/// of its own near-identical `enum State { case loading; case loaded(X); case failed(String) }`
/// — one generic type, one set of call-site patterns to learn, instead of a bespoke state
/// enum per screen that drifts in shape over time. A form/submission ViewModel (validation
/// + save-in-flight, e.g. `AddEditItemViewModel`) is a genuinely different shape and should
/// keep its own properties rather than being forced into this one.
enum ViewState<Value> {
    /// The true first fetch — nothing has ever loaded yet, so there's nothing to show
    /// underneath a spinner.
    case loading
    case loaded(Value)
    /// A new fetch is in flight (search term changed, pull-to-refresh, "load more") while a
    /// previous value is still worth showing. The UI should keep rendering that value —
    /// optionally with a subtle progress indicator — instead of blanking to a full-screen
    /// spinner the way a bare `.loading` would. Use `load()`-style methods' existing
    /// `state.value` (below) to decide `.loading` vs `.refreshing` without duplicating that
    /// check at every call site.
    case refreshing(Value)
    case failed(String)
}

extension ViewState {
    /// The current value, if any — present for `.loaded` and `.refreshing`, `nil` for
    /// `.loading`/`.failed`.
    var value: Value? {
        switch self {
        case .loaded(let value), .refreshing(let value):
            return value
        case .loading, .failed:
            return nil
        }
    }
}
