/// Discards everything — inject into a ViewModel under test so assertions aren't tied to
/// SwiftUI state, matching `NoOpEventLogger`.
struct NoOpAlertService: AlertService {
    func showAlert(_ alert: AlertContent) {}
    func showToast(_ toast: ToastContent) {}
}
