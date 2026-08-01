import SwiftUI

/// Centralizes the handful of colors this template's chrome uses — swap a value here (e.g.
/// `accent` to a brand color) instead of hunting down every `.foregroundStyle(.red)` call
/// site. Same role as `Spacing.swift`: named tokens over inline `Color` literals.
/// `AlertCenterOverlay`'s `AlertTint -> Color` mapping reads from here too, so an alert's
/// "destructive" icon and a form's validation-error text always match.
enum Colors {
    static let accent = Color.accentColor
    static let destructive = Color.red
    static let success = Color.green
    static let warning = Color.orange
    static let secondaryText = Color.secondary
}
