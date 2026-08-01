import Foundation

/// Every localizable string in the app, in one place — the `Localizable.xcstrings`
/// counterpart to `AppError`'s "one error vocabulary": one canonical Swift symbol per
/// catalog key instead of `String(localized: "...")` literals scattered (and possibly
/// re-typed slightly differently) across every View/ViewModel that needs one. Add a case
/// here, and the matching key to `Resources/Localizable.xcstrings`, for any new
/// user-facing string — don't reach for an inline `String(localized:)` instead.
///
/// Domain-layer (imports only Foundation, per the Architecture rules) because `AppError`
/// needs these too — Presentation depends on Domain, never the other way round, so this
/// couldn't live under `Presentation/Shared/` without inverting that dependency.
enum AppStrings {
    // MARK: - Home

    static let items = String(localized: "Items")
    static let searchItems = String(localized: "Search items")
    static let addItem = String(localized: "Add Item")
    static let selectAnItem = String(localized: "Select an Item")
    static let noItems = String(localized: "No Items")
    static let couldntLoadItems = String(localized: "Couldn't Load Items")
    static let couldntLoadMoreItems = String(localized: "Couldn't Load More Items")
    static let delete = String(localized: "Delete")

    // MARK: - Item detail / add-edit form

    static let edit = String(localized: "Edit")
    static let couldntLoadItem = String(localized: "Couldn't Load Item")
    static let newItem = String(localized: "New Item")
    static let editItem = String(localized: "Edit Item")
    static let title = String(localized: "Title")
    static let detail = String(localized: "Detail")
    static let priority = String(localized: "Priority")
    static let none = String(localized: "None")
    static let cancel = String(localized: "Cancel")
    static let save = String(localized: "Save")

    // MARK: - Settings / About

    static let settings = String(localized: "Settings")
    static let about = String(localized: "About")
    static let version = String(localized: "Version")
    static let environment = String(localized: "Environment")
    static let aboutThisTemplate = String(localized: "About This Template")
    static let appName = String(localized: "AppTemplate")
    static let aboutDescription = String(
        localized: "A starting point following Clean Architecture: Core, Domain, Data, Presentation. See README.md."
    )

    // MARK: - Tab bar

    static let home = String(localized: "Home")

    // MARK: - Auth

    static let logIn = String(localized: "Log In")
    static let logOut = String(localized: "Log Out")
    static let email = String(localized: "Email")
    static let password = String(localized: "Password")
    static let invalidCredentials = String(localized: "Invalid email or password.")

    // MARK: - Alerts / toasts

    static let ok = String(localized: "OK")
    static let couldntOpenLocalStorage = String(localized: "Couldn't Open Local Storage")
    static let usingTemporaryInMemoryStore = String(localized: "Using a temporary in-memory store for this session.")
    static let itemSaved = String(localized: "Item Saved")
    static let couldntDeleteItem = String(localized: "Couldn't Delete Item")

    // MARK: - AppError messages

    static let invalidRequestURL = String(localized: "The request URL is invalid.")
    static let noInternetConnection = String(localized: "No internet connection.")
    static let serverUnexpectedResponse = String(localized: "The server returned an unexpected response.")
    static let couldntReadServerResponse = String(localized: "Couldn't read the server's response.")
    static let couldntSaveYourData = String(localized: "Couldn't save your data.")
    static let couldntLoadYourData = String(localized: "Couldn't load your data.")
    static let requestedItemNotFound = String(localized: "The requested item couldn't be found.")

    // Functions, not stored properties, for the parameterized messages — formatted via
    // String(format:) so the localized template stays one catalog entry ("%@ can't be
    // empty.") regardless of the argument, instead of one entry per distinct field name.
    static func requestFailed(statusCode: Int) -> String {
        String(format: String(localized: "The request failed (status %d)."), statusCode)
    }

    static func fieldCannotBeEmpty(_ field: String) -> String {
        String(format: String(localized: "%@ can't be empty."), field)
    }

    static func fieldTooLong(_ field: String, max: Int) -> String {
        String(format: String(localized: "%@ can't be longer than %d characters."), field, max)
    }
}
