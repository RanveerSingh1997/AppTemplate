import Foundation

/// Standard shape for any "fetch a resource, then show it" screen. Every such ViewModel
/// (`HomeViewModel`, `ItemDetailViewModel`, ...) declares `state: ViewState<Value>` instead
/// of its own near-identical `enum State { case loading; case loaded(X); case failed(String) }`
/// — one generic type, one set of call-site patterns to learn, instead of a bespoke state
/// enum per screen that drifts in shape over time. A form/submission ViewModel (validation
/// + save-in-flight, e.g. `AddEditItemViewModel`) is a genuinely different shape and should
/// keep its own properties rather than being forced into this one.
enum ViewState<Value> {
    case loading
    case loaded(Value)
    case failed(String)
}
