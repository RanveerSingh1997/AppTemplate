import Foundation

/// Reads a per-environment default (passed in at `AppDependencies` construction), then
/// lets `UserDefaults` win if a device-local override has been set — e.g. from a future
/// debug menu. Never a network fetch, so this needs no backend. Swap for a real
/// remote-config SDK's client later without touching anything that calls `isEnabled(_:)`.
struct UserDefaultsFeatureFlagService: FeatureFlagService {
    private let defaults: [FeatureFlag: Bool]
    private let userDefaults: UserDefaults

    init(defaults: [FeatureFlag: Bool] = [:], userDefaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.userDefaults = userDefaults
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        let key = "featureFlag.\(flag.rawValue)"
        if userDefaults.object(forKey: key) != nil {
            return userDefaults.bool(forKey: key)
        }
        return defaults[flag] ?? false
    }
}
