import Foundation

/// Generic shape for "create a new X, or edit an existing one" — the form-ViewModel
/// counterpart to `ViewState<Value>`'s "fetch and show" shape. Any add/edit screen
/// (`AddEditItemViewModel` today, a future one tomorrow) declares `FormMode<Value>`
/// instead of its own `enum Mode { case create; case edit(X) }` — same reasoning as
/// `ViewState`: one generic type beats a bespoke one per screen that happens to look
/// identical (see README's "Architecture rules" for what that duplication costs).
enum FormMode<Value: Equatable>: Equatable {
    case create
    case edit(Value)
}
