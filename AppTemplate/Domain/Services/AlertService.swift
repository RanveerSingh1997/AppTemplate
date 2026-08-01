import Foundation

/// Presents blocking alerts and transient toast banners without a ViewModel touching
/// SwiftUI state directly. Inject this protocol type into a ViewModel's initializer — same
/// as `ReachabilityService`/`EventLogger` — so tests can swap in `NoOpAlertService`.
/// `@MainActor`, not `Sendable`: every caller already runs on the main actor, and the real
/// implementation (`AlertCenter`) is the `@Observable` state a root view renders.
@MainActor
protocol AlertService {
    func showAlert(_ alert: AlertContent)
    func showToast(_ toast: ToastContent)
}

/// `showAlert(title:message:)`/`showToast(_:)` — the common case, a single-OK-button alert
/// or a plain toast — stay one-liners; reach for `AlertContent`/`ToastContent` directly
/// only when you need an icon, extra buttons, or a toast action.
extension AlertService {
    func showAlert(title: String, message: String) {
        showAlert(AlertContent(title: title, message: message))
    }

    func showToast(_ message: String) {
        showToast(ToastContent(message: message))
    }
}

/// Semantic color, not a `Color` — Domain imports only Foundation (see the README's
/// Architecture rules #4), so this can't be `SwiftUI.Color`. `AlertCenterOverlay`
/// (Presentation) is the one place that maps each case to an actual color; everything
/// else — including this whole file — stays SwiftUI-free.
enum AlertTint {
    case accent
    case destructive
    case success
    case warning
    case neutral
}

enum AlertTextAlignment {
    case leading
    case center
    case trailing
}

/// A button's role decides both its visual weight (`.primary` renders filled/prominent,
/// `.secondary` renders plain) and, for `.destructive`, its color — the two things "is this
/// the main action" and "is this a dangerous one" that matter for an alert button, without
/// exposing raw color/style knobs a caller would have to get right themselves.
enum AlertButtonRole {
    case primary
    case secondary
    case destructive
}

struct AlertButtonConfig: Identifiable {
    let id = UUID()
    let title: String
    var role: AlertButtonRole
    let action: () -> Void

    init(title: String, role: AlertButtonRole = .secondary, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }
}

struct AlertContent: Identifiable {
    /// `.automatic` stacks vertically once there are more than 2 buttons (matches how
    /// native `.alert` behaves) — pass `.horizontal`/`.vertical` to override that for a
    /// specific alert.
    enum ButtonLayout {
        case automatic
        case horizontal
        case vertical
    }

    let id = UUID()
    var icon: String?
    var iconTint: AlertTint
    let title: String
    let message: String
    var messageAlignment: AlertTextAlignment
    var buttons: [AlertButtonConfig]
    var buttonLayout: ButtonLayout

    init(
        title: String,
        message: String,
        icon: String? = nil,
        iconTint: AlertTint = .accent,
        messageAlignment: AlertTextAlignment = .center,
        buttons: [AlertButtonConfig] = [],
        buttonLayout: ButtonLayout = .automatic
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.iconTint = iconTint
        self.messageAlignment = messageAlignment
        self.buttons = buttons.isEmpty ? [AlertButtonConfig(title: AppStrings.ok, role: .primary, action: {})] : buttons
        self.buttonLayout = buttonLayout
    }
}

struct ToastContent: Identifiable {
    struct Action {
        let title: String
        let handler: () -> Void
    }

    let id = UUID()
    var icon: String?
    let message: String
    var tint: AlertTint
    var duration: TimeInterval
    var action: Action?

    init(
        message: String,
        icon: String? = nil,
        tint: AlertTint = .neutral,
        duration: TimeInterval = 2.5,
        action: Action? = nil
    ) {
        self.message = message
        self.icon = icon
        self.tint = tint
        self.duration = duration
        self.action = action
    }
}
