# Contributing

## Setup

```sh
brew install xcodegen swiftlint
xcodegen generate
open AppTemplate.xcodeproj
```

Full setup/scheme details are in the [README](README.md#getting-started). For a
programmatic build/run/test loop (no Xcode UI needed), see
`.claude/skills/run-apptemplate/SKILL.md`.

## Before opening a PR

```sh
xcodegen generate
swiftlint lint --strict
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate-Dev -configuration Debug-DEV \
  -destination 'generic/platform=iOS Simulator'
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate-Dev -configuration Debug-DEV \
  -destination 'platform=iOS Simulator,name=<any available iPhone — see `xcrun simctl list devices available`>'
```

CI (`.github/workflows/ci.yml`) runs all four on every push and PR to `main` — this is
just how to see the same result locally before pushing.

## Ground rules

This template enforces a handful of architecture rules — see the README's
["Architecture rules"](README.md#architecture-rules-enforced-not-just-documented)
section for the full list and reasoning. The short version:

- No concrete `Data` type (`...Impl`) referenced from `Presentation/` — SwiftLint fails
  the build on this one.
- No new singletons (`static let shared =`) under `Domain/`, `Data/`, or `Presentation/`
  — also SwiftLint-enforced.
- Every new repository/service ships a protocol (`Domain/Repositories` or
  `Domain/Services`) plus a real implementation and a mock (`Data/Repositories` or
  `Data/Persistence`/`Core/Services`) — follow `ItemRepository` as the reference.
- A "fetch and show" ViewModel declares `ViewState<Value>`; a "create or edit" ViewModel
  declares `FormMode<Value>`; a view rendering a `ViewState<Value>` uses `ViewStateView`
  instead of writing its own `switch`. Don't add a fourth near-identical shape — extend
  one of these three, or open an issue first if none of them fit.
- Every user-facing string is an `AppStrings` symbol (`Domain/AppStrings.swift`) backed by
  a `Resources/Localizable.xcstrings` entry — never a literal passed straight to
  `Text`/`Button`/`AppError`/etc. See the README's "Localization" section.
- A ViewModel that needs to show an alert or toast takes `AlertService` through its
  initializer and calls `showAlert(title:message:)`/`showToast(_:)` — never its own
  `@State` alert flag. See the README's "Alerts & toasts" section, including why the real
  implementation is named `AlertCenter`, not `AlertServiceImpl`.
- Any color/font/SF Symbol in `Presentation/` is a `Colors`/`Typography`/`Icons` symbol
  (`Presentation/Shared/`) — never a `.foregroundStyle(.red)`/`.font(.title.bold())`/
  `"trash"` literal. See the README's "Design tokens" section.
- Any text field with an error message is `ValidatedTextField`; any button reaches for
  `.buttonStyle(.primary/.secondary/.destructive)` — never a hand-rolled `TextField` +
  error `Text` pairing, or ad hoc `.tint(...)`. See the README's "Reusable form components"
  section.
- Concrete `@Observable` app-shell state a root view binds to directly (`AuthSessionStore`,
  `NavigationCoordinator`, `AlertCenter`) stays out of ViewModels — a ViewModel returns
  data (a token, a saved item), the View acts on it. See the README's "Authentication"
  section for why `LoginViewModel` doesn't hold `AuthSessionStore`.

## Commits and PRs

- Keep commits focused — one logical change per commit, with a message explaining *why*
  (the README's own commit history is a reasonable model: see `git log`).
- Update the README alongside any change to the folder structure, architecture rules, or
  shared `Presentation/` types (`ViewState`, `FormMode`, `ViewStateView`,
  `LoadFailureView`, `AppStrings`, `AlertCenterOverlay`, `Colors`, `Typography`, `Icons`,
  `ValidatedTextField`, `ButtonStyles`, `AuthSessionStore`) — it's meant to stay accurate,
  not just be a first-day snapshot.
- Run the "Before opening a PR" commands above; CI will re-run them regardless, but
  catching a lint/test failure locally is faster than round-tripping through CI.
