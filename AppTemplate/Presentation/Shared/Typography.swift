import SwiftUI

/// Centralizes the handful of font styles this template's chrome uses. Same role as
/// `Spacing.swift`/`Colors.swift`: named tokens over inline `.font(...)` literals, so a
/// type-scale change touches one file instead of every screen that happens to use `.title`.
enum Typography {
    /// `SplashView`'s app icon — a hero image on an otherwise-empty screen.
    static let heroIcon = Font.system(size: 64)
    /// `SettingsView`'s About icon — smaller, inline with a title/description below it.
    static let sectionIcon = Font.system(size: 48)
    /// `SplashView`'s app name, `ItemDetailView`'s item title.
    static let heading = Font.title.bold()
    /// `SettingsView`'s About screen title.
    static let subheading = Font.title2.bold()
    /// `ItemDetailView`'s detail text — same as SwiftUI's default, named for consistency so
    /// "always reach for `Typography.xxx`" has no unstated exception.
    static let body = Font.body
    /// `HomeSplitView`'s priority label under each item's title.
    static let caption = Font.caption
}
