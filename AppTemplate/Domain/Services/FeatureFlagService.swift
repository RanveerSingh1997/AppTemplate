import Foundation

/// One example flag — replace with your own as real features need gating. Demonstrates
/// the seam; nothing in the app reads this yet, the same way `ReachabilityService` isn't
/// consumed by any repository yet either.
enum FeatureFlag: String, CaseIterable, Sendable {
    case exampleFeature = "example_feature"
}

/// Feature-flag seam. Not consumed anywhere yet — check `isEnabled(_:)` from a ViewModel
/// the same way `AlertService`/`ItemRepository` are injected, once a real flag exists to
/// gate something on.
protocol FeatureFlagService: Sendable {
    func isEnabled(_ flag: FeatureFlag) -> Bool
}
