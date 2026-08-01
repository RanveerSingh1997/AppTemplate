import Foundation

/// Centralizes every SF Symbol name this template's chrome uses — same role as
/// `Spacing`/`Colors`/`Typography`: a named constant instead of a `"pencil"`/`"trash"`
/// string literal repeated at (or slightly misspelled between) call sites. Swapping an
/// icon means editing this file, not grepping for every `Image(systemName:)`/
/// `Label(systemImage:)` that happens to use it.
enum Icons {
    // MARK: - App chrome

    static let appIcon = "app.fill"              // SplashView's hero icon
    static let aboutIcon = "app.badge.checkmark"  // SettingsView's About icon
    static let homeTab = "list.bullet"            // MainTabView's Home tab
    static let settingsTab = "gearshape"          // MainTabView's Settings tab

    // MARK: - Actions

    static let add = "plus"       // HomeSplitView's add-item toolbar button
    static let edit = "pencil"    // ItemDetailView's edit button
    static let delete = "trash"   // HomeSplitView's delete swipe action

    // MARK: - Empty / failure states

    static let emptyList = "tray"                       // HomeSplitView's "No Items"
    static let noSelection = "sidebar.left"              // HomeSplitView's "Select an Item"
    static let failure = "exclamationmark.triangle"      // LoadFailureView's ViewState.failed icon

    // MARK: - Alerts / toasts

    static let warning = "exclamationmark.triangle.fill"  // AlertContent's warning icon
    static let success = "checkmark.circle.fill"           // ToastContent's success icon
}
