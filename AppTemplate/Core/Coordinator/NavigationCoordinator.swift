import Observation
import SwiftUI

/// Push destinations reachable from within a tab's own NavigationStack.
/// Add cases here as you add drill-down screens; `.navigationDestination(for: AppRoute.self)`
/// maps each case to a view.
enum AppRoute: Hashable {
    case about
}

/// Which tab `MainTabView` shows. A coordinator property (like `selectedItemID`/
/// `settingsPath`) rather than local `@State` on `MainTabView`, so a deep link — handled
/// before `MainTabView` even exists yet, e.g. while `LoginView` is still showing — can
/// still set it; see `NavigationCoordinator.handle(url:)`.
enum AppTab: Hashable {
    case home
    case settings
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
    /// Drives `MainTabView`'s `TabView(selection:)`.
    var selectedTab: AppTab = .home

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

    /// Maps a deep link to navigation state. Safe to call before `MainTabView` exists (e.g.
    /// a link opened while `LoginView` is still showing, from `AppContainerView`'s
    /// `.onOpenURL`) — `NavigationCoordinator` is one instance that outlives the
    /// login/logout transition, so `MainTabView` just picks up whatever was already set
    /// once it mounts.
    ///
    /// Recognizes:
    /// - `apptemplate://items/<id>` — Home tab, that item selected
    /// - `apptemplate://settings` — Settings tab
    /// - `apptemplate://settings/about` — Settings tab, About pushed
    ///
    /// Also the seam for universal links: add the Associated Domains entitlement and an
    /// `apple-app-site-association` file and `.onOpenURL` starts receiving `https://` links
    /// too — nothing here has to change, since `URL.host`/`.pathComponents` work the same
    /// way for both.
    @discardableResult
    func handle(url: URL) -> Bool {
        let components = url.pathComponents.dropFirst() // drops the leading "/"
        switch url.host {
        case "items":
            guard let id = components.first else { return false }
            selectedTab = .home
            selectItem(id)
            return true
        case "settings":
            selectedTab = .settings
            popSettingsToRoot()
            if components.first == "about" {
                push(.about)
            }
            return true
        default:
            return false
        }
    }
}
