import Foundation

/// Which backend/config environment is running — driven by the active build config
/// (Debug-DEV/Release-DEV/Debug-QA/... in project.yml), not by Debug vs Release. QA can be
/// built in either Debug or Release, so `#if DEBUG` alone can't distinguish these.
enum AppEnvironment: String {
    case dev = "Dev"
    case qa = "QA"
    case prod = "Prod"

    static var current: AppEnvironment {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "ENVName") as? String,
              let environment = AppEnvironment(rawValue: raw) else {
            return .dev
        }
        return environment
    }
}
