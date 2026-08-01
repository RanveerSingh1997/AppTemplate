import Foundation

/// All flags on by default — new-in-progress features stay visible in Dev without extra
/// setup. Override individual flags via `set(_:for:)` in tests that need one off.
final class MockFeatureFlagService: FeatureFlagService, @unchecked Sendable {
    private var overrides: [FeatureFlag: Bool]

    init(overrides: [FeatureFlag: Bool] = [:]) {
        self.overrides = overrides
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        overrides[flag] ?? true
    }

    func set(_ isEnabled: Bool, for flag: FeatureFlag) {
        overrides[flag] = isEnabled
    }
}
