import Observation
import SwiftUI

/// Push destinations reachable from within a tab's own NavigationStack.
/// Add cases here as you add drill-down screens; `.navigationDestination(for: AppRoute.self)`
/// maps each case to a view.
enum AppRoute: Hashable {
    case about
}

/// Which item-form sheet is presented, and in which mode. `Identifiable` so it can drive
/// `.sheet(item:)` directly.
enum ItemFormRoute: Identifiable, Equatable {
    case create
    case edit(Item)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let item): return "edit-\(item.id)"
        }
    }
}

/// Single source of truth for cross-view navigation state, shared via dependency injection
/// (not a singleton) so it stays testable and each tab can own its own stack.
@Observable
@MainActor
final class NavigationCoordinator {
    /// Drives the Home tab's NavigationSplitView (sidebar selection <-> detail column).
    /// SwiftUI adapts this automatically: a two-column layout on iPad/Mac, a push-style
    /// single column on iPhone — no manual size-class branching required.
    var selectedItemID: String?

    /// Drives the Settings tab's own push/pop stack.
    var settingsPath = NavigationPath()

    /// Drives the create/edit item sheet, from either the list or the detail column.
    var presentedItemForm: ItemFormRoute?

    func presentItemForm(_ route: ItemFormRoute) {
        presentedItemForm = route
    }

    func dismissItemForm() {
        presentedItemForm = nil
    }

    func push(_ route: AppRoute) {
        settingsPath.append(route)
    }

    func popSettings() {
        guard !settingsPath.isEmpty else { return }
        settingsPath.removeLast()
    }

    func popSettingsToRoot() {
        settingsPath.removeLast(settingsPath.count)
    }

    func selectItem(_ id: String?) {
        selectedItemID = id
    }
}
