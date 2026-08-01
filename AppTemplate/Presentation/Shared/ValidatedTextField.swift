import SwiftUI

/// A `TextField` plus its own inline error message, styled from `Typography`/`Colors`/
/// `Spacing` — the shape `AddEditItemView`'s Title field had before this was extracted (a
/// bare `TextField` with a form-wide error `Text` below the whole form, not scoped to the
/// field it was actually about). Reach for this instead of hand-rolling that
/// `TextField` + `if let errorMessage { Text(...) }` pairing on the next form.
struct ValidatedTextField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            TextField(title, text: $text, axis: axis)
            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.caption)
                    .foregroundStyle(Colors.destructive)
            }
        }
    }
}

#Preview("No error") {
    Form {
        ValidatedTextField(title: "Title", text: .constant("Buy groceries"))
    }
}

#Preview("With error") {
    Form {
        ValidatedTextField(title: "Title", text: .constant(""), errorMessage: "Title can't be empty.")
    }
}
