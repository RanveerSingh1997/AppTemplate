# AppTemplate

A starting-point SwiftUI iOS app: Clean Architecture (Core / Domain / Data / Presentation),
a Coordinator for navigation, one small DI container, a repository pattern with mock/live
swapping, and a DTO -> Domain -> Persistence mapping layer. It's a rebuilt version of the
pattern used in the Iris app — the good parts kept, several known rough edges fixed (see
below), and a few things made *more* rigorous than the original (unified error taxonomy,
per-environment build configs, SwiftLint enforced from day one).

Builds and runs immediately in the simulator — no backend, no config needed. It ships one
complete example feature with full CRUD (list, detail, create, edit, delete, validation —
backed by `Item`) wired through every layer, plus a Settings tab, so you can see the whole
pattern working before you copy it.

## Requirements

- Xcode 16+, iOS 17+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the
  `.xcodeproj` is generated from `project.yml`, not committed. **Don't hand-edit the
  `.xcodeproj`** for structural changes (new files, new targets); edit `project.yml` and
  run `xcodegen generate` instead, or the two will drift.
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`) — runs as a
  build phase; if it's not installed, the build prints a warning and continues rather than
  failing.

## Getting started

```sh
xcodegen generate
open AppTemplate.xcodeproj
```

Three schemes exist — **AppTemplate-Dev**, **AppTemplate-QA**, **AppTemplate-Prod** — each
with its own Debug/Release build configs, bundle identifier, app display name, and API base
URL (see `AppTemplate/Config/*.xcconfig`). Dev runs against the in-memory mock repository
with no backend needed; QA/Prod use the real network+SwiftData-cache repository.

Run any scheme on any iPhone or iPad simulator — `TARGETED_DEVICE_FAMILY` is universal and
the Home tab uses `NavigationSplitView`, which SwiftUI adapts automatically (two-column
sidebar+detail on iPad/Mac, single push-style column on iPhone). No manual size-class
branching needed.

## Making it your app

1. Rename the target/product: in `project.yml` replace `AppTemplate` (target name,
   `PRODUCT_NAME`) and the three `Config/*.xcconfig` files' `APP_BUNDLE_IDENTIFIER`/
   `APP_NAME` values with your app's identity, then `xcodegen generate` again. Rename the
   `AppTemplate/` and `AppTemplateTests/` folders and `TemplateApp.swift`'s `@main` struct
   to match.
2. Replace the `Item` domain model (`Domain/Models/Item.swift`), `ItemDTO`
   (`Data/DTOs/ItemDTO.swift`), `CachedItem` (`Data/Persistence/CachedItem.swift`),
   `ItemMapper` (`Data/Mappers/ItemMapper.swift`), `ItemRepository` protocol, and its two
   implementations with your real entity. Keep the same shape: Domain owns the protocol +
   model, Data owns the DTO/persistence types, the mapper, and both repository
   implementations; Presentation only ever talks to the `ItemRepository` protocol.
3. Wire it into `AppDependencies.swift` — add one stored property and one branch in
   `init()` per new dependency, and one typed `make*ViewModel()` factory per screen.
   Keep each dependency's mock/live branch local to that one dependency; don't let
   `init()` grow into a single wall of ternaries shared across unrelated services.
4. Add real app icon images to `Resources/Assets.xcassets/AppIcon.appiconset` (currently
   an empty placeholder — fine for simulator builds, required before archiving).
5. Point `BASE_URL` in each `Config/*.xcconfig` at your real per-environment API.

## Adding a new feature/screen

Follow the `Home`/`Item` example (list, detail, create/edit form, delete):

1. **Domain**: model + repository protocol (`Domain/Models`, `Domain/Repositories`).
2. **Data**: `ItemDTO` (network shape), an `EntityMapper` conformance mapping DTO <->
   persistence entity, and two repository implementations (live, mock).
3. **Presentation**: `@Observable @MainActor` ViewModel + `View`, taking the ViewModel
   in its initializer (never constructing it itself — that's `AppDependencies`' job).
   Validation errors and save/load failures both surface through `AppError`.
4. **AppDependencies**: one stored `let` + one `make*ViewModel()` factory method.
5. **Navigation**: if it needs a push destination, add a case to `AppRoute` and a branch
   in the relevant `.navigationDestination(for:)`. For a modal form, follow
   `ItemFormRoute`/`presentedItemForm` — a `NavigationCoordinator`-owned, `Identifiable`
   route driving `.sheet(item:)`. If it's a new tab, add it to `MainTabView`.
6. **Tests**: a ViewModel test against the mock repository, plus a mock-repository test
   for any new CRUD method — see `AppTemplateTests/HomeViewModelTests.swift` and
   `AppTemplateTests/MockItemRepositoryImplTests.swift`.

## What's built but not yet wired in

These exist as protocol + mock + real implementation, registered on `AppDependencies`,
because most real apps need them soon — but nothing in the app calls them yet. Wire one in
(pass it into a new/existing type's initializer, the same way `apiClient` is passed to
`ItemRepositoryImpl`) when a concrete feature needs it; don't reach for `.shared` instead.

- **`SecureStorageService`** (`Domain/Services/SecureStorageService.swift`) — Keychain-
  backed token/credential storage. Plug in when you add auth.
- **`ReachabilityService`** (`Domain/Services/ReachabilityService.swift`) — connectivity
  check via `NWPathMonitor`. Plug into a repository (check before a network call) or an
  offline banner.
- **`EventLogger`** (`Domain/Services/EventLogger.swift`) — leveled logging seam
  (`ConsoleEventLogger` prints to stdout today; swap for a real analytics/crash-reporting
  SDK's logger later without touching any call site).

These are intentionally untested beyond compiling — a test that only proves the mock
returns what you told it to return isn't real coverage. Test them once something depends
on them.

## What's deliberately *not* here (add only when you need it)

- **Localization** — plain string literals for now. Add a String Catalog
  (`Localizable.xcstrings`) when you actually need a second language.
- **Auth/login flow** — business-specific; bolt it on as its own feature module
  following the same Domain/Data/Presentation shape, using `SecureStorageService` above.
- **Auth headers, retry, or request logging on `APIClient`** — it already covers every
  HTTP verb via one `send(_ request: APIRequest)` method, so add these as a decorator
  wrapping `URLSessionAPIClient` (or a second `APIClientInterceptor`-style hook) rather
  than new protocol methods or a bigger single type.

## Fixes vs. the app this was templated from

- **No `fatalError` on bad/missing config.** `AppConfiguration` falls back to a dev
  default and only *throws* in QA/Prod; the one remaining `fatalError`
  (in `PersistenceFactory`) fires only if even an in-memory SwiftData store can't be
  created, a genuine framework-level failure, not a config mistake.
- **No singletons.** Every dependency is constructor-injected via `AppDependencies`;
  nothing reaches for `.shared` from inside a ViewModel or repository.
- **No hardcoded color scheme.** Nothing calls `.preferredColorScheme(.light)` — the
  app follows the system appearance in light and dark.
- **No type-erased "God" view factory.** There's no single switch statement that
  downcasts a type-erased view model per screen and `fatalError`s on a mismatch.
  `AppDependencies` exposes one typed factory method per screen instead, so each
  screen's wiring is checked by the compiler.
- **Adaptive by construction.** `NavigationSplitView` replaces manual
  `UIHostingController` presentation/size-class branching for list/detail navigation.
- **Environment is a first-class config, not `#if DEBUG`.** QA can be built Debug or
  Release, so `AppEnvironment` reads an `ENVName` Info.plist key set per-scheme, instead
  of conflating "which backend" with "which build type."

## Architecture notes

- **Layering (Clean Architecture's dependency rule)**: `Domain/` imports only
  `Foundation` — no SwiftData, no URLSession, no SwiftUI. `Data/` depends inward on
  `Domain`'s protocols. `Presentation/` depends only on `Domain` protocols, never on
  concrete `Data` types. Only `App/AppDependencies.swift` (the composition root) is
  allowed to know about concrete `Data` types.
- **`AppError`** (`Domain/AppError.swift`) is the one error vocabulary every layer
  throws — network/persistence/validation/configuration — so ViewModels switch on one
  type instead of learning what each dependency happens to throw.
- **`EntityMapper`** (`Domain/Protocols/EntityMapper.swift`) is the one place that knows
  both a DTO's shape and a persistence entity's shape; a renamed/reshaped API field only
  requires editing the mapper, never every call site that touches `Item`.
