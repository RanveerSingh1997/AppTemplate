import Observation

@Observable
@MainActor
final class SplashViewModel {
    private(set) var isReady = false

    /// Placeholder for real startup work (auth check, remote config, migrations).
    func prepare() async {
        try? await Task.sleep(for: .seconds(0.6))
        isReady = true
    }
}
