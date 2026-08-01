import SwiftUI

/// The shape every `ViewState.failed` case renders as — `HomeSplitView` and
/// `ItemDetailView` both had their own identical `ContentUnavailableView(title,
/// systemImage: "exclamationmark.triangle", description:)` call before this was extracted.
struct LoadFailureView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: "exclamationmark.triangle", description: Text(message))
    }
}

#Preview {
    // The message here is preview-only (never shown for real — AppError.errorDescription
    // supplies the real message), so it's not in Localizable.xcstrings; the title reuses
    // the real AppStrings key since HomeSplitView passes this exact one.
    LoadFailureView(title: AppStrings.couldntLoadItems, message: "The network connection appears to be offline.")
}
