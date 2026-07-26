# AppTemplate

[![Sponsor](https://img.shields.io/badge/sponsor-%E2%9D%A4-db61a2?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/RanveerSingh1997)

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
2. **Data**: a case in `APIEndpoint` for each new route (never a path string built inline
   in a repository method), `ItemDTO` (network shape), an `EntityMapper` conformance
   mapping DTO <-> persistence entity, and two repository implementations (live, mock).
3. **Presentation**: `@Observable @MainActor` ViewModel + `View`, taking the ViewModel
   in its initializer (never constructing it itself — that's `AppDependencies`' job).
   Validation errors and save/load failures both surface through `AppError`. If the
   ViewModel's job is "fetch a resource, show it," declare `state: ViewState<Value>`
   (`Presentation/ViewState.swift`) — don't declare a new `enum State { case loading,
   loaded, failed }` per screen (see "Shared `ViewState`" below for why). A form/submission
   ViewModel (validation + save-in-flight, like `AddEditItemViewModel`) is a different
   shape and keeps its own properties instead.
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
  backed token/credential storage. Already read by `AuthHeaderInterceptor` (see below);
  an auth feature just needs to *write* to it after login — nothing else to wire up.
- **`ReachabilityService`** (`Domain/Services/ReachabilityService.swift`) — connectivity
  check via `NWPathMonitor`. Plug into a repository (check before a network call) or an
  offline banner.

`EventLogger` (`Domain/Services/EventLogger.swift`) *is* wired in — `LoggingInterceptor`
uses it to log every request's method/path/status/duration. `ConsoleEventLogger` (prints
to stdout) is the only implementation, though; swap it for a real analytics/crash-reporting
SDK's logger later without touching `LoggingInterceptor` or any other call site.

These are intentionally untested beyond compiling — a test that only proves the mock
returns what you told it to return isn't real coverage. Test them once something depends
on them.

## What's deliberately *not* here (add only when you need it)

- **Localization** — plain string literals for now. Add a String Catalog
  (`Localizable.xcstrings`) when you actually need a second language.
- **Auth/login flow** — business-specific; bolt it on as its own feature module
  following the same Domain/Data/Presentation shape. Once it exists, have it call
  `secureStorageService.set(_:forKey: SecureStorageKey.authToken)` after login/refresh —
  `URLSessionAPIClient` already reads that key on every request (see below), so nothing
  in the networking layer needs to change.

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

## Networking (`Data/Networking/`)

`URLSessionAPIClient` is meant to be the last time you touch the transport layer, not a
starting sketch. Every piece below is a real, tested implementation, not a stub:

- **Auth header injection**: `AuthHeaderInterceptor` reads `SecureStorageKey.authToken`
  from `SecureStorageService` on every request and sets `Authorization: Bearer <token>`.
  Wired into `AppDependencies`' QA/Prod `URLSessionAPIClient` already — an auth feature
  only needs to `set(_:forKey:)` that key after login; the interceptor picks it up live,
  no other change needed. Before login it reads `nil` and leaves requests alone.
- **Interceptor chain**: `APIClientInterceptor` is the general seam (`adapt(_:)` to modify
  outgoing requests, `didReceive(response:data:for:duration:)` to observe every response)
  for anything else per-request — request signing, a correlation ID. `LoggingInterceptor`
  is a second concrete conformance, wired in alongside the auth one, logging method/path/
  status/duration through `EventLogger` (never headers/body, so it's safe to leave on).
- **401 -> refresh -> retry**: pass `authTokenRefresher` to `URLSessionAPIClient` once you
  have a token-refresh call. On a 401 it's invoked once; on success the original request
  is retried (picking up whatever the interceptors now read); on failure the refresh's
  error propagates. `nil` today because there's no auth flow yet to refresh from.
- **Transient-failure retry**: `RetryPolicy` retries 5xx/timeout responses with a linear
  backoff — `.get` only by default (`.default`), since auto-retrying `.post`/`.put`/
  `.delete` risks double-submitting a request whose response was merely lost. Opt other
  verbs in per-client if you know a given endpoint is idempotent. Separate from, and
  composes with, the 401-retry above.
- **Real server error messages**: a non-2xx response has its body decoded as
  `APIErrorResponse` (tries `message`/`error`/`errorMessage`/`detail` keys — adjust to your
  API's actual shape) and that message surfaces through `AppError`, instead of a generic
  "status 422" with no explanation of what was actually wrong.
- **Timeouts**: `URLSessionAPIClient.makeSession(requestTimeout:resourceTimeout:)` sets
  explicit timeouts (30s/60s defaults) instead of relying on `URLSession.shared`'s.
- **Certificate pinning**: `PinnedCertificateValidator` pins by server public-key SHA-256
  hash. Disabled by default (a template can't ship real hashes for a real backend) — pass
  `pinnedPublicKeyHashes` to `URLSessionAPIClient.init`/`makeSession` to enable; both the
  main session and the separate upload session (see below) enforce the same pins.
- **File upload with progress**: `upload(_:file:)` returns `AsyncStream<UploadEvent>`
  (`.progress(Double)`, `.completed(Data)`, `.failed(AppError)`) via a real multipart
  implementation (`MultipartFormData`, `UploadProgressObserver`) — the one case with a
  second `APIClient` method, since progress-over-time can't fit `send`'s single-value shape.
- **Query parameters & JSON bodies as data, not string concatenation**: `APIRequest.queryItems`
  (`[URLQueryItem]`) and the `APIRequest(path:method:json:)` initializer (auto-encodes
  `Encodable`, sets `Content-Type: application/json`) replace hand-built query strings and
  the per-call-site `JSONEncoder().encode(...)` boilerplate `ItemRepositoryImpl` used to have.
- **Every HTTP verb, one `send` method**: `APIRequest.method` + `.requiresAuth` cover
  GET/POST/PUT/DELETE and public-vs-authenticated endpoints without new protocol methods.
- **Status codes in one place**: `HTTPStatusCode.swift` is the only file with a bare `401`
  or a `200..<300` range — `isSuccess`/`isClientError`/`isServerError`/`unauthorized` are
  used everywhere else, so a status-handling change never means hunting for every inline
  range across `APIClient.swift`, `FileUpload.swift`, and `APIClientInterceptor.swift`.

Tested directly (not just through the mock repository) in
`AppTemplateTests/URLSessionAPIClientTests.swift`, which stubs `URLProtocol` to exercise
the auth header, error-message decoding, and retry-policy logic against real (intercepted)
HTTP round-trips.

## Architecture rules (enforced, not just documented)

These aren't style preferences — two of them are wired into `.swiftlint.yml`'s
`custom_rules` with `severity: error`, which makes the SwiftLint build phase (see
`project.yml`) exit non-zero and **fail the build**, not just print a warning. A developer
can't quietly route around the pattern by "just this once" reaching for a concrete type
or a singleton — the build stops them.

1. **Every swappable dependency is defined by a protocol; Presentation depends only on the
   protocol.** `ItemRepository` (protocol) + `ItemRepositoryImpl`/`MockItemRepositoryImpl`
   (implementations) is the shape to copy for every new repository/service. Enforced by
   the `no_concrete_impl_outside_composition_root` custom rule: any `...Impl`/`...ServiceImpl`
   identifier appearing under `Presentation/` fails the build. Only `AppDependencies` (the
   composition root) may construct one.
2. **No new singletons.** Enforced by the `no_new_singletons` custom rule: a `static let
   shared =`/`static var shared =` anywhere under `Domain/`, `Data/`, or `Presentation/`
   fails the build. Add the dependency to `AppDependencies` and inject it through an
   initializer instead — see "No singletons" under Fixes, below.
3. **Every new repository/service ships a protocol, a real implementation, and a mock**
   (`Domain/Repositories/ItemRepository.swift` +
   `Data/Repositories/{ItemRepositoryImpl,MockItemRepositoryImpl}.swift`). Not mechanically
   enforced (SwiftLint can't verify a matching file exists) — this one is on code review,
   but the existing three files are the reference to copy exactly.
4. **Layering follows Clean Architecture's dependency rule.** `Domain/` imports only
   `Foundation` — no SwiftData, no URLSession, no SwiftUI. `Data/` depends inward on
   `Domain`'s protocols. `Presentation/` depends only on `Domain` protocols, never on
   concrete `Data` types (this is rule 1, restated as the general principle it's an
   instance of).
5. **A "fetch and show" ViewModel declares `ViewState<Value>`, never its own state enum.**
   `HomeViewModel` and `ItemDetailViewModel` both declare `state: ViewState<[Item]>`/
   `ViewState<Item>` from the one shared type in `Presentation/ViewState.swift`, instead of
   each writing its own `enum State { case loading, loaded, failed }`. Not mechanically
   enforced the way rules 1–2 are (no SwiftLint check for "did you reuse the shared type"),
   but it's the one existing example both current ViewModels already follow — copy it.

   This is deliberately the *opposite* of Iris's actual pattern: Iris has ~18 separate
   `XViewState`/`XViewStates` files (one per screen — `SplashViewStates`,
   `LoginViewStates`, `AccountsListingViewStates`, ...), each hand-writing a near-identical
   loading/loaded/error shape, several with manually-written `Equatable` conformances that
   Swift could have synthesized, and one with a doc comment copy-pasted from a *different*
   screen's state file that was never updated ("Represents the possible states of the
   login process" — on `SplashViewStates.swift`). Five separate `ViewStateTests`/
   `ViewStateTests2`–`5` files testing that duplicated shape is the natural result of not
   extracting it once. `ViewState<Value>` exists so this template doesn't repeat that.

   `ViewState<Value>` has a `.refreshing(Value)` case, distinct from `.loading`, for exactly
   one reason: a re-fetch (search term changed, pull-to-refresh, delete-then-reload) should
   keep showing the previous list while it completes, not blank the screen to a spinner the
   way transitioning back to `.loading` would. `HomeViewModel.load()` already does this —
   `state.value.map(ViewState.refreshing) ?? .loading` — and `HomeSplitView`/`ItemDetailView`
   render `.loaded`/`.refreshing` identically, showing a toolbar `ProgressView()` only for
   the latter. **`.refreshing` deliberately doesn't say *why*** (search vs. load-more vs.
   pull-to-refresh) — `ViewState` only answers "do I have data, is something in flight,"
   not every possible reason a screen might refetch. If you add search or pagination and the
   UI needs to distinguish them (e.g. a load-more spinner belongs at the bottom of the list,
   not the toolbar), add a purpose-specific property to that ViewModel — `isLoadingMore:
   Bool`, a `searchText: String` whose non-empty state implies "searching" — rather than
   growing `ViewState` with a `reason` enum every screen would have to handle whether or not
   it's relevant. Keep the shared type generic; put feature-specific "why" on the feature.

## Consuming multiple fetched data sources on one screen

`ViewState<Value>` isn't "the one state of the screen" — `Value` is scoped to *one fetch*.
A screen that needs several independently-fetched things doesn't outgrow it; it just
declares one `ViewState<X>` property per thing. `AddEditItemViewModel` is the concrete
example, not a hypothetical one:

```swift
var title: String                                  // the form's own fields —
var detail: String                                  // not fetched, not ViewState
private(set) var priorityOptions: ViewState<[Priority]> = .loading   // fetched independently
```

`loadPriorities()` and the form's own `save()`/validation run on separate schedules —
`AddEditItemView` calls `.task { await viewModel.loadPriorities() }` alongside the form
fields, so the priority picker loads concurrently with (not blocking, and not blocked by)
the rest of the sheet appearing. Add a third fetched thing (categories, assignees,
whatever) the same way: one more `ViewState<Y>` property, one more `.task`.

**When to reach for a composite `Value` instead**: if two or more fetches must always
load/fail/refresh *together* — there's no sensible way to show the screen with only one
of them loaded — bundle them into one struct and fetch that as a unit instead of
juggling N independent `ViewState` properties. `HomeViewModel`/`HomeScreenData` are the
concrete example: showing an item's priority *label* (not just its raw `priorityID`) needs
both the item list and the priority lookup resolved before the list is meaningful.

```swift
// Presentation/Home/HomeScreenData.swift
struct HomeScreenData {
    let items: [Item]
    let priorities: [Priority]
    func priorityName(for item: Item) -> String? { /* looks up item.priorityID */ }
}

// HomeViewModel
private(set) var state: ViewState<HomeScreenData> = .loading

func load() async {
    state = state.value.map(ViewState.refreshing) ?? .loading
    async let items = repository.fetchItems(search: search)
    async let priorities = priorityRepository.fetchPriorities()
    state = .loaded(HomeScreenData(items: try await items, priorities: try await priorities))
}
```

`async let` starts both fetches concurrently and cancels whichever hasn't finished if the
other throws — no orphaned request on failure. `HomeSplitView` reads `data.priorityName(for:)`
to show each row's priority as a subtitle. (One deliberate simplification: `load()` re-fetches
priorities on every reload, including every debounced search — fine while that's cheap
lookup data; cache it separately if that ever measurably matters.)

Neither approach requires changing `ViewState` itself — it stays exactly as generic as
`Presentation/ViewState.swift` already defines it either way.

## Architecture notes

- **`AppError`** (`Domain/AppError.swift`) is the one error vocabulary every layer
  throws — network/persistence/validation/configuration — so ViewModels switch on one
  type instead of learning what each dependency happens to throw.
- **`EntityMapper`** (`Domain/Protocols/EntityMapper.swift`) is the one place that knows
  both a DTO's shape and a persistence entity's shape; a renamed/reshaped API field only
  requires editing the mapper, never every call site that touches `Item`.
