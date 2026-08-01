import SwiftUI

/// Renders `AlertCenter`'s current alert and toast on top of `content`. A custom dialog and
/// banner, not `.alert(...)` — native SwiftUI alerts can't show an icon, can't align the
/// message, and can't give a button its own color/prominence, all of which `AlertContent`/
/// `ToastContent` (`Domain/Services/AlertService.swift`) let a caller configure. Attach once,
/// at the app root (`AppContainerView`); every ViewModel below just calls `AlertService
/// .showAlert`/`.showToast`, with no `@State` or binding of its own.
struct AlertCenterOverlay<Content: View>: View {
    let alertCenter: AlertCenter
    @ViewBuilder let content: Content

    var body: some View {
        content
            .overlay {
                if let alert = alertCenter.activeAlert {
                    AlertDialogView(alert: alert, onDismiss: alertCenter.dismissAlert)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = alertCenter.activeToast {
                    ToastView(toast: toast, onDismiss: alertCenter.dismissToast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.default, value: alertCenter.activeAlert?.id)
            .animation(.default, value: alertCenter.activeToast?.id)
    }
}

extension View {
    func alertCenterOverlay(_ alertCenter: AlertCenter) -> some View {
        AlertCenterOverlay(alertCenter: alertCenter) { self }
    }
}

private extension AlertTint {
    var color: Color {
        switch self {
        case .accent: return Colors.accent
        case .destructive: return Colors.destructive
        case .success: return Colors.success
        case .warning: return Colors.warning
        case .neutral: return Colors.secondaryText
        }
    }
}

private extension AlertTextAlignment {
    var swiftUIValue: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

private struct AlertDialogView: View {
    let alert: AlertContent
    let onDismiss: () -> Void

    private var isVertical: Bool {
        switch alert.buttonLayout {
        case .vertical: return true
        case .horizontal: return false
        case .automatic: return alert.buttons.count > 2
        }
    }

    var body: some View {
        ZStack {
            // No tap-to-dismiss on the scrim — an alert is meant to block until a button
            // is chosen, same as native `.alert`; only `buttons` dismiss it.
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: Spacing.medium) {
                if let icon = alert.icon {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundStyle(alert.iconTint.color)
                }
                VStack(spacing: Spacing.small) {
                    Text(alert.title)
                        .font(.headline)
                    Text(alert.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(alert.messageAlignment.swiftUIValue)
                .frame(maxWidth: .infinity, alignment: alert.messageAlignment.frameAlignment)

                buttonStack
            }
            .padding(Spacing.large)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(Spacing.large)
        }
    }

    @ViewBuilder
    private var buttonStack: some View {
        if isVertical {
            VStack(spacing: Spacing.small) { buttons }
        } else {
            HStack(spacing: Spacing.small) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        ForEach(alert.buttons) { button in
            Button(button.title) {
                button.action()
                onDismiss()
            }
            .buttonStyle(.bordered)
            .tint(button.role == .secondary ? .primary : button.role.tint.color)
            .fontWeight(button.role == .primary ? .semibold : .regular)
            .frame(maxWidth: isVertical ? .infinity : nil)
        }
    }
}

private extension AlertButtonRole {
    var tint: AlertTint {
        switch self {
        case .primary: return .accent
        case .secondary: return .neutral
        case .destructive: return .destructive
        }
    }
}

private extension AlertTextAlignment {
    var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

private struct ToastView: View {
    let toast: ToastContent
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            if let icon = toast.icon {
                Image(systemName: icon)
                    .foregroundStyle(toast.tint.color)
            }
            Text(toast.message)
            if let action = toast.action {
                Button(action.title) {
                    action.handler()
                    onDismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.medium)
        .background(.thinMaterial, in: Capsule())
        // Clears MainTabView's floating tab bar (83pt) with headroom to spare — this
        // overlay sits above the TabView, so it doesn't get that bar's safe-area inset for
        // free the way in-tab content would.
        // ponytail: a fixed constant, not measured per-screen; revisit if a screen without
        // a tab bar (e.g. a future full-screen flow) wants a toast and this leaves too much
        // empty space below it.
        .padding(.bottom, 100)
        .onTapGesture { onDismiss() }
    }
}

#Preview("Alert — default OK button") {
    let center = AlertCenter()
    center.showAlert(title: AppStrings.couldntDeleteItem, message: "The network connection appears to be offline.")
    return Color.clear.alertCenterOverlay(center)
}

#Preview("Alert — icon + primary/secondary/destructive buttons") {
    let center = AlertCenter()
    center.showAlert(
        AlertContent(
            title: "Delete Item?",
            message: "This can't be undone.",
            icon: Icons.warning,
            iconTint: .warning,
            buttons: [
                AlertButtonConfig(title: AppStrings.cancel, role: .secondary, action: {}),
                AlertButtonConfig(title: AppStrings.delete, role: .destructive, action: {})
            ],
            buttonLayout: .horizontal
        )
    )
    return Color.clear.alertCenterOverlay(center)
}

#Preview("Toast — plain") {
    let center = AlertCenter()
    center.showToast(AppStrings.itemSaved)
    return Color.clear.alertCenterOverlay(center)
}

#Preview("Toast — icon + action") {
    let center = AlertCenter()
    center.showToast(
        ToastContent(
            message: "Item Deleted",
            icon: Icons.success,
            tint: .success,
            action: ToastContent.Action(title: "Undo", handler: {})
        )
    )
    return Color.clear.alertCenterOverlay(center)
}
