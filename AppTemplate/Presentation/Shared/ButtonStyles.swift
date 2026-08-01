import SwiftUI

/// Three full-width button styles, matching `AlertButtonRole`'s primary/secondary/
/// destructive vocabulary — `.buttonStyle(.primary)` etc., the same call pattern as
/// SwiftUI's own `.buttonStyle(.bordered)`. Built from `Colors`/`Typography`/`Spacing`, so a
/// rebrand (new accent color, new corner radius) touches those files, not every button.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.small)
            .foregroundStyle(.white)
            .background(Colors.accent, in: RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.body)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.small)
            .foregroundStyle(Colors.accent)
            .background(Colors.secondaryText.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.small)
            .foregroundStyle(.white)
            .background(Colors.destructive, in: RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}

#Preview {
    VStack(spacing: Spacing.medium) {
        Button("Save", action: {}).buttonStyle(.primary)
        Button("Cancel", action: {}).buttonStyle(.secondary)
        Button("Delete", action: {}).buttonStyle(.destructive)
    }
    .padding()
}
