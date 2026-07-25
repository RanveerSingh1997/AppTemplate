import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    let appVersion: String
    let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        appVersion = "\(version) (\(build))"
    }
}
