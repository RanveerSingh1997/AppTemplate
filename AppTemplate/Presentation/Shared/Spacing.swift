import Foundation

/// Named spacing scale so new views pick from this instead of each hand-writing its own
/// `spacing: 12`/`spacing: 16` - `SettingsView`, `ItemDetailView`, and `SplashView` did
/// exactly that independently before this existed. Extend with `xsmall`/`xlarge` etc. if a
/// new view genuinely needs a value outside this range; don't add a one-off numeric literal
/// next to it instead.
enum Spacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
}
