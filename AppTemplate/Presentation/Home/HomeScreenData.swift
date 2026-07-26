import Foundation

/// The concrete "must load together" example: showing an item's priority *label* (not
/// just its raw `priorityID`) needs both `items` and `priorities` resolved before the list
/// is meaningful — there's no useful way to render the screen with only one of them
/// loaded. That's what makes this one composite `Value` for one `ViewState`, rather than
/// two separate `ViewState` properties the way `AddEditItemViewModel.priorityOptions` is
/// independent of its own form fields (see README's "Consuming multiple fetched data
/// sources on one screen" for both patterns side by side).
struct HomeScreenData {
    let items: [Item]
    let priorities: [Priority]

    /// `nil` if the item has no priority set, or its `priorityID` doesn't match anything in
    /// `priorities` (e.g. deleted/renamed server-side between the two fetches).
    func priorityName(for item: Item) -> String? {
        guard let priorityID = item.priorityID else { return nil }
        return priorities.first { $0.id == priorityID }?.name
    }
}
