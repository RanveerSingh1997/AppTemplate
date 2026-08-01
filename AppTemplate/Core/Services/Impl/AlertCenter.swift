import Foundation
import Observation

/// The one real `AlertService` — used in every environment (unlike `ReachabilityService`'s
/// dev/qa-prod split; there's no dev-time reason to fake an alert, only to render one).
/// Named without the `...ServiceImpl` suffix, deliberately: `AppContainerView` binds to
/// this concrete type directly to read `activeAlert`/`activeToast`, the same way it binds
/// to `NavigationCoordinator` — both are live presentation state a root view owns, not a
/// swappable Data-layer implementation Presentation must stay protocol-blind to. (Naming it
/// `...ServiceImpl` would also trip `no_concrete_impl_outside_composition_root`, which is
/// the point — this reference from `Presentation/Shared/AlertCenterOverlay.swift` is
/// intentional, unlike a real `RepositoryImpl` leaking out of the composition root.)
@Observable
@MainActor
final class AlertCenter: AlertService {
    private(set) var activeAlert: AlertContent?
    private(set) var activeToast: ToastContent?
    private var toastDismissTask: Task<Void, Never>?

    func showAlert(_ alert: AlertContent) {
        activeAlert = alert
    }

    func showToast(_ toast: ToastContent) {
        toastDismissTask?.cancel()
        activeToast = toast
        let toastID = toast.id
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(toast.duration))
            guard !Task.isCancelled, self?.activeToast?.id == toastID else { return }
            self?.activeToast = nil
        }
    }

    func dismissAlert() {
        activeAlert = nil
    }

    func dismissToast() {
        toastDismissTask?.cancel()
        activeToast = nil
    }
}
