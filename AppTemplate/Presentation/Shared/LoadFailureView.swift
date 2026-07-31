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
    LoadFailureView(title: "Couldn't Load Items", message: "The network connection appears to be offline.")
}
