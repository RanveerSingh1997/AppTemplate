# AppTemplate

[![CI](https://github.com/RanveerSingh1997/AppTemplate/actions/workflows/ci.yml/badge.svg)](https://github.com/RanveerSingh1997/AppTemplate/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-%E2%9D%A4-db61a2?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/RanveerSingh1997)

A starting-point SwiftUI iOS app: Clean Architecture (Core / Domain / Data / Presentation),
a Coordinator for navigation, one small DI container, a repository pattern with mock/live
swapping, and a DTO -> Domain -> Persistence mapping layer, with a unified error taxonomy,
per-environment build configs, and SwiftLint enforced from day one.

Builds and runs immediately in the simulator — no backend, no config needed. It ships one
complete example feature with full CRUD (list, detail, create, edit, delete, validation —
backed by `Item`) wired through every layer, plus a Settings tab, so you can see the whole
pattern working before you copy it.

## Folder structure

```
AppTemplate/
├── project.yml                  # xcodegen spec — the source of truth; .xcodeproj is generated
├── .swiftlint.yml                # includes the two enforced architecture rules (custom_rules)
│
├── AppTemplate/
│   ├── App/                     # composition root + app shell — the only layer allowed to
│   │   │                        # know about concrete Data types (see Architecture rules)
│   │   ├── TemplateApp.swift          # @main
│   │   ├── AppContainerView.swift     # splash -> login/main-tab switch, startup-error alert
│   │   └── AppDependencies.swift      # builds every dependency once, exposes make*ViewModel()
│   │
│   ├── Config/                  # per-environment xcconfig (Dev/QA/Prod) — bundle id, app
│   │   │                        # name, API base URL; read via AppConfiguration. The
│   │   │                        # apptemplate:// URL scheme (see "Deep linking") is
│   │   │                        # registered in project.yml's target.info, not here —
│   │   │                        # it's the same across environments
│   │   ├── DevConfig.xcconfig
│   │   ├── QAConfig.xcconfig
│   │   └── ProdConfig.xcconfig
│   │
│   ├── Core/                    # infrastructure that isn't Domain/Data/Presentation
│   │   ├── Config/                    # AppEnvironment, AppConfiguration (reads xcconfig values)
│   │   ├── Coordinator/                # NavigationCoordinator, AppRoute, AppTab, ItemFormRoute,
│   │   │                                # AuthSessionStore — see "Authentication" and
│   │   │                                # "Deep linking"
│   │   └── Services/
│   │       ├── Impl/                   # real implementations (Keychain, NWPathMonitor, console,
│   │       │                           # AlertCenter — see "Alerts & toasts" for its naming)
│   │       └── Mocks/                   # in-memory/no-op stand-ins used in Dev
│   │
│   ├── Domain/                  # protocols + models only — imports just Foundation, no
│   │   │                        # SwiftData/URLSession/SwiftUI (see Architecture rules #4)
│   │   ├── AppError.swift              # the one error vocabulary every layer throws
│   │   ├── AppStrings.swift             # every localizable string, one Swift symbol each —
│   │   │                                # here (not Presentation/Shared) since AppError needs
│   │   │                                # it too, and Domain can't depend on Presentation
│   │   ├── Models/                      # Item, Priority, AuthSession — domain-facing shapes
│   │   ├── Protocols/                   # LocalTimestamped
│   │   ├── Repositories/                 # ItemRepository, PriorityRepository, AuthRepository
│   │   └── Services/                     # SecureStorageService, ReachabilityService,
│   │                                      # EventLogger, AlertService, FeatureFlagService
│   │
│   ├── Data/                     # concrete implementations of Domain's protocols
│   │   ├── DTOs/                        # ItemDTO, PriorityDTO, AuthDTOs — network shapes
│   │   ├── Mappers/                      # EntityMapper, ItemMapper — the one place that
│   │   │                                  # knows DTO + persistence shape
│   │   ├── Networking/                   # APIClient, APIEndpoint, interceptors, retry, pinning, upload
│   │   ├── Persistence/                   # CachedItem (SwiftData), PersistenceFactory,
│   │   │                                   # SwiftDataStore, ItemCache, SwiftDataItemCache
│   │   │                                   # — see "Persistence"
│   │   └── Repositories/                   # ItemRepositoryImpl/Mock, PriorityRepositoryImpl/Mock,
│   │                                        # AuthRepositoryImpl/MockAuthRepositoryImpl
│   │
│   ├── Presentation/              # ViewModel + View per feature — depends only on Domain
│   │   │                          # protocols, never a concrete Data type
│   │   ├── Shared/                      # generic, feature-agnostic — reused across screens
│   │   │   ├── ViewState.swift               # shared loading/loaded/refreshing/failed generic
│   │   │   ├── FormMode.swift                 # shared create/edit(Value) generic
│   │   │   ├── LoadFailureView.swift           # shared ViewState.failed rendering
│   │   │   ├── ViewStateView.swift             # shared ViewState<Value> switch — renders the
│   │   │   │                                   # loading/failed/loaded-or-refreshing view for you
│   │   │   ├── Spacing.swift                    # named spacing scale — small/medium/large
│   │   │   ├── Colors.swift                      # named color tokens — see "Design tokens"
│   │   │   ├── Typography.swift                   # named font tokens — see "Design tokens"
│   │   │   ├── Icons.swift                         # named SF Symbol tokens — see "Design tokens"
│   │   │   ├── ValidatedTextField.swift             # TextField + inline error — see
│   │   │   │                                        # "Reusable form components"
│   │   │   ├── ButtonStyles.swift                    # .primary/.secondary/.destructive
│   │   │   │                                         # button styles — see "Reusable form
│   │   │   │                                         # components"
│   │   │   └── AlertCenterOverlay.swift               # renders AlertCenter's alert/toast — see
│   │   │                                               # "Alerts & toasts"
│   │   ├── Splash/
│   │   ├── Auth/                        # LoginViewModel, LoginView — see "Authentication"
│   │   ├── Home/                        # list/detail/create-edit-delete + search — the main
│   │   │                                # example feature; HomeScreenData is the composite-
│   │   │                                # Value example, AddEditItemViewModel.priorityOptions
│   │   │                                # is the separate-ViewState-property example
│   │   ├── Settings/
│   │   └── Main/                         # MainTabView
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       └── Localizable.xcstrings         # String Catalog — source language en; see
│                                          # "Localization" below
│
└── AppTemplateTests/              # one test file per production file it covers — see
                                    # "Architecture rules" for what's tested vs. deliberately not
```

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

1. Rename the target/product: `Scripts/bootstrap-new-project.sh <NewName>
   [bundle-id-prefix]` automates this step — target/`PRODUCT_NAME`, the three
   `Config/*.xcconfig` files' `APP_BUNDLE_IDENTIFIER`/`APP_NAME`, the `AppTemplate/`/
   `AppTemplateTests/` folders, `TemplateApp.swift`'s `@main` struct, `.swiftlint.yml`'s
   `included:` paths, and every test's `@testable import`, then runs `xcodegen generate`
   for you. Run it with `--dry-run` first to preview; see the script's own header comment
   for exactly what it does and doesn't touch (schemes and the `.xcodeproj` filename stay
   as `AppTemplate-Dev`/`AppTemplate.xcodeproj` — cosmetic, not asked for by this list, and
   documented in the script). Or do it by hand: in `project.yml` replace `AppTemplate`
   (target name, `PRODUCT_NAME`) and the three `Config/*.xcconfig` files'
   `APP_BUNDLE_IDENTIFIER`/`APP_NAME` values with your app's identity, then `xcodegen
   generate` again. Rename the `AppTemplate/` and `AppTemplateTests/` folders and
   `TemplateApp.swift`'s `@main` struct to match.
2. Replace the `Item` domain model (`Domain/Models/Item.swift`), `ItemDTO`
   (`Data/DTOs/ItemDTO.swift`), `CachedItem`/`ItemCache`/`SwiftDataItemCache`
   (`Data/Persistence/`), `ItemMapper` (`Data/Mappers/ItemMapper.swift`), `ItemRepository`
   protocol, and its two implementations with your real entity. Keep the same shape: Domain
   owns the protocol + model, Data owns the DTO/persistence types, the mapper, the cache
   seam, and both repository implementations; Presentation only ever talks to the
   `ItemRepository` protocol — see "Persistence" for why `ItemRepositoryImpl` itself talks
   to `ItemCache`, not SwiftData directly.
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
   in a repository method), `ItemDTO` (network shape), and two repository implementations
   (live, mock). If the feature needs offline caching, add an `EntityMapper` conformance
   mapping DTO <-> persistence entity and a cache protocol the live implementation depends
   on — follow `ItemMapper`/`ItemCache`/`SwiftDataItemCache` (see "Persistence"); skip all
   three if it doesn't (`PriorityRepositoryImpl` has none).
3. **Presentation**: `@Observable @MainActor` ViewModel + `View`, taking the ViewModel
   in its initializer (never constructing it itself — that's `AppDependencies`' job).
   Validation errors and save/load failures both surface through `AppError`. If the
   ViewModel's job is "fetch a resource, show it," declare `state: ViewState<Value>`
   (`Presentation/Shared/ViewState.swift`) — don't declare a new `enum State { case loading,
   loaded, failed }` per screen (see "Shared `ViewState`" below for why). If it's instead
   "create a new X or edit an existing one," declare `mode: FormMode<Value>`
   (`Presentation/Shared/FormMode.swift`, e.g. `AddEditItemViewModel`'s `FormMode<Item>`) rather
   than its own `enum Mode { case create; case edit(X) }` — same reasoning as `ViewState`,
   applied to the other recurring ViewModel shape this template has.
4. **AppDependencies**: one stored `let` + one `make*ViewModel()` factory method.
5. **Navigation**: if it needs a push destination, add a case to `AppRoute` and a branch
   in the relevant `.navigationDestination(for:)`. For a modal form, follow
   `ItemFormRoute`/`presentedItemForm` — a `NavigationCoordinator`-owned, `Identifiable`
   route driving `.sheet(item:)`. If it's a new tab, add it to `MainTabView`.
6. **Tests**: a ViewModel test against the mock repository, plus a mock-repository test
   for any new CRUD method — see `AppTemplateTests/HomeViewModelTests.swift` and
   `AppTemplateTests/MockItemRepositoryImplTests.swift`.
7. **Preview**: a `#Preview` block wiring the mock repositories directly (see any existing
   view for the pattern) — every view in this template has one, so Xcode's canvas is a
   faster loop than the simulator for iterating on layout. Constructing a `Mock*Impl`
   directly is the one place Presentation code is allowed to reach for a concrete type
   instead of a protocol (`no_concrete_impl_outside_composition_root` exempts `Mock*Impl`
   for exactly this) — a real `...Impl` still isn't allowed and still fails the build.
   Use `Spacing.small`/`.medium`/`.large` (`Presentation/Shared/Spacing.swift`) for any
   `VStack`/`HStack` spacing, and `Colors`/`Typography`/`Icons` (`Presentation/Shared/`) for
   any color/font/SF Symbol, instead of a numeric/`Color`/`.font(...)`/`"symbol.name"`
   literal — see "Design tokens". Use `ValidatedTextField` and
   `.buttonStyle(.primary/.secondary/.destructive)` (`Presentation/Shared/`) for any text
   field with an error message or any button, instead of hand-rolling either — see
   "Reusable form components".
8. **Strings**: add a symbol to `Domain/AppStrings.swift` and a matching key to
   `Resources/Localizable.xcstrings` for any new UI text, then reference `AppStrings.xxx`
   at the call site — never a literal `"..."` passed straight to `Text`/`Button`/etc. See
   "Localization" below.

## What's built but not yet wired in

These exist as protocol + mock + real implementation, registered on `AppDependencies`,
because most real apps need them soon — but nothing in the app calls them yet. Wire one in
(pass it into a new/existing type's initializer, the same way `apiClient` is passed to
`ItemRepositoryImpl`) when a concrete feature needs it; don't reach for `.shared` instead.

- **`ReachabilityService`** (`Domain/Services/ReachabilityService.swift`) — connectivity
  check via `NWPathMonitor`. Plug into a repository (check before a network call) or an
  offline banner.
- **`FeatureFlagService`** (`Domain/Services/FeatureFlagService.swift`) —
  `isEnabled(_ flag: FeatureFlag) -> Bool`. `UserDefaultsFeatureFlagService` (real) checks
  a per-environment default, then lets a `UserDefaults` override (e.g. from a future debug
  menu) win — no backend needed. `FeatureFlag.exampleFeature` is a placeholder case;
  replace it with your own as real features need gating, the same way `Item` is a
  placeholder domain model (see "Making it your app").

`SecureStorageService` (`Domain/Services/SecureStorageService.swift`) *is* wired in —
`AuthHeaderInterceptor` reads it on every request, `AuthSessionStore` writes to it on
login/logout (see "Authentication"). `KeychainSecureStorageService` is the only real
implementation; nothing about that call site changes if you swap it for a different
secure-storage mechanism.

`EventLogger` (`Domain/Services/EventLogger.swift`) *is* wired in — `LoggingInterceptor`
uses it to log every request's method/path/status/duration. `ConsoleEventLogger` (prints
to stdout) is the only implementation, though; swap it for a real analytics/crash-reporting
SDK's logger later without touching `LoggingInterceptor` or any other call site.

`AlertService` (`Domain/Services/AlertService.swift`) *is* wired in too — `HomeViewModel`
shows an alert on a failed delete, `AddEditItemViewModel` shows a toast on a successful
save. See "Alerts & toasts" below for the full pattern.

These are intentionally untested beyond compiling — a test that only proves the mock
returns what you told it to return isn't real coverage. Test them once something depends
on them.

## What's deliberately *not* here (add only when you need it)

- **Token refresh** — `URLSessionAPIClient.authTokenRefresher` is the seam (401 -> refresh
  -> retry the original request once), but `AppDependencies` passes `nil` since there's no
  refresh-token concept yet (see "Authentication" — `AuthSession` is just an access token
  today). Add a `refresh(refreshToken:)` method to `AuthRepository` once your backend
  issues refresh tokens, and pass a closure calling it as `authTokenRefresher` — nothing
  else about the request pipeline changes.
- **Signup, password reset, biometric unlock** — same reasoning: bolt these onto the
  `Auth`/`AuthRepository` shape `LoginView`/`AuthRepositoryImpl` already establish, rather
  than growing `LoginViewModel` into a catch-all auth ViewModel.

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

## Persistence (`Data/Persistence/`)

`ItemRepositoryImpl` doesn't import SwiftData, and never sees `ModelContext` or
`CachedItem` — it depends on `ItemCache` (a protocol), the same way it depends on
`APIClient` (a protocol) instead of `URLSession` directly:

```swift
@MainActor
protocol ItemCache {
    func upsert(_ dtos: [ItemDTO])
    func pruneStale(against dtos: [ItemDTO])
    func fetchAll(matching search: String?) throws -> [Item]
    func fetchByID(_ id: String) -> Item?
    func delete(id: String)
}
```

`SwiftDataItemCache` is the only real conformance, and the only file (besides
`CachedItem.swift` itself) that imports SwiftData for items. Swapping persistence tech
later — Core Data, SQLite, a flat file — means writing one new `ItemCache` conformance and
changing one line in `AppDependencies`; none of `ItemRepositoryImpl`'s network/
cache-fallback/pagination-safety logic has to change, because it was never written against
SwiftData's types in the first place.

**`SwiftDataStore<Entity: PersistentModel>`** is a second, smaller layer underneath that:
generic fetch/insert/delete against any `@Model` type, so `SwiftDataItemCache` calls
`store.fetch()` instead of writing `modelContext.fetch(FetchDescriptor<CachedItem>())` at
each of its call sites. `fetch(_:)` takes an optional `FetchDescriptor<Entity>` — pass one
with a `predicate` to query by field instead of fetching every row and scanning in Swift;
`SwiftDataItemCache.fetchByID`/`delete` do exactly that against `CachedItem`'s unique `id`,
where `upsert`/`pruneStale` still call `store.fetch()` with no predicate since they
genuinely need every cached row to diff against. It's still SwiftData-specific —
`PersistentModel`/`FetchDescriptor`/`#Predicate` are SwiftData's own vocabulary, so this
doesn't (and isn't meant to) hide *that* framework dependency the way `ItemCache` hides it
from `ItemRepositoryImpl`. It exists to remove the boilerplate repetition of working with
SwiftData directly, not to make SwiftData itself swappable — `ItemCache` is what does that.
Add a second `SwiftData*Cache` for another entity later and it reuses the same store.

`ItemMapper` (`Data/Mappers/ItemMapper.swift`) also takes `SwiftDataStore<CachedItem>`
rather than a raw `ModelContext`, for the insert its `toEntity` does — so `SwiftDataItemCache`
itself never touches `ModelContext` outside its own `init` (where it constructs `store` and
hands the raw context off, immediately). `EntityMapper` (`Data/Mappers/EntityMapper.swift`,
the protocol `ItemMapper` conforms to) lives in `Data/`, not `Domain/`, despite the
generic-sounding name — its `associatedtype Entity: PersistentModel` makes it a
persistence-framework-aware type by definition, the same reason `ItemCache`/
`SwiftDataStore` live there too.

Tested against a fake `ItemCache` (`AppTemplateTests/ItemRepositoryImplTests.swift`'s
`InMemoryItemCache`) rather than a real `ModelContainer` — proof the abstraction actually
decouples `ItemRepositoryImpl` from SwiftData, and the only way this template's own
cache-fallback/upsert/pruneStale/pagination-safety logic gets to run in a fast, synchronous
unit test at all.

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
   `ViewState<Item>` from the one shared type in `Presentation/Shared/ViewState.swift`, instead of
   each writing its own `enum State { case loading, loaded, failed }`. Not mechanically
   enforced the way rules 1–2 are (no SwiftLint check for "did you reuse the shared type"),
   but it's the one existing example both current ViewModels already follow — copy it.

   This is deliberately the *opposite* of the anti-pattern it's meant to head off: a
   codebase with a separate `XViewState`/`XViewStates` file per screen (`SplashViewStates`,
   `LoginViewStates`, `AccountsListingViewStates`, ...), each hand-writing a near-identical
   loading/loaded/error shape, several with manually-written `Equatable` conformances that
   Swift could have synthesized, and one with a doc comment copy-pasted from a *different*
   screen's state file that was never updated ("Represents the possible states of the
   login process" on a splash screen's state file). Five near-identical `ViewStateTests`
   files testing that duplicated shape is the natural result of not extracting it once.
   `ViewState<Value>` exists so this template doesn't repeat that.

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

6. **A view rendering a `ViewState<Value>` uses `ViewStateView`, never its own
   `switch state { case .loading: ... }`.** `HomeSplitView`'s sidebar, `ItemDetailView`'s
   body, and `AddEditItemView`'s `priorityPicker` each wrote that switch by hand before
   `Presentation/Shared/ViewStateView.swift` extracted it — same duplication `ViewState<Value>`
   itself was created to avoid, one layer up, in the *view* instead of the *ViewModel*.
   `ViewStateView(state:failureTitle:loaded:)` covers the common case (loading spinner,
   full-screen `LoadFailureView`, your content for `.loaded`/`.refreshing`); pass an
   explicit `failed:` builder instead of `failureTitle:` for an inline failure
   presentation, as `AddEditItemView.priorityPicker` does (a plain secondary-style `Text`,
   not a full `LoadFailureView`, since it's one row inside a form, not the whole screen).

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

**When to reach for a composite `Value` instead**: if two or more fetches build one
screen's worth of data and there's no sensible `Value` with only one of them loaded, bundle
them into one struct and fetch that as a unit instead of juggling N independent `ViewState`
properties. `HomeViewModel`/`HomeScreenData` are the concrete example: showing an item's
priority *label* (not just its raw `priorityID`) needs both the item list and the priority
lookup.

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
    async let itemsTask = repository.fetchItems(search: search)
    async let prioritiesTask = priorityRepository.fetchPriorities()
    do {
        let items = try await itemsTask
        let priorities: [Priority]
        do {
            priorities = try await prioritiesTask
        } catch {
            alertService.showAlert(title: AppStrings.couldntLoadPriorities, message: error.localizedDescription)
            priorities = []
        }
        state = .loaded(HomeScreenData(items: items, priorities: priorities))
    } catch {
        state = .failed(error.localizedDescription)
    }
}
```

**Bundling two fetches into one `Value` doesn't mean they have to fail *together*.** Items
are essential — `HomeScreenData` isn't meaningful without them, so a failed items fetch is
`.failed`, same as any single-`ViewState` screen. Priorities are secondary — they only
upgrade each row from "unlabeled" to "labeled" — so a failed priorities fetch alerts and
degrades to `priorities: []` (which `priorityName(for:)` already handles fine) rather than
blanking a list that loaded successfully. This asymmetry matters concretely here:
`ItemRepositoryImpl` has an offline cache fallback and `PriorityRepositoryImpl` deliberately
doesn't (see its own doc comment) — treating both fetches as equally load-bearing would
mean going offline defeats that cache fallback every time, since the *unrelated* priorities
fetch would fail the whole screen regardless of whether items themselves loaded fine. Decide
this per fetch, not by rule: if both truly are essential (there's genuinely nothing useful
to show with only one), let both failures reach the outer `catch` instead of swallowing one.

Both fetches still start concurrently via `async let` — nesting the priorities `do`/`catch`
inside the outer one only changes how each *result* is handled once both are in flight, not
when they start; sequencing the `await`s themselves would turn `max(items-time,
priorities-time)` latency into their sum. `HomeSplitView` reads `data.priorityName(for:)`
to show each row's priority as a subtitle. (One deliberate simplification: `load()` re-fetches
priorities on every reload, including every debounced search — fine while that's cheap
lookup data; cache it separately if that ever measurably matters.)

Neither approach requires changing `ViewState` itself — it stays exactly as generic as
`Presentation/Shared/ViewState.swift` already defines it either way.

## Pagination

`ItemRepository.fetchItems(search:)` returns one page; a second protocol method,
`fetchMoreItems(search:offset:)`, returns the next one — `offset` is just "how many items
the caller already has," so `HomeViewModel` never needs to know a page size:

```swift
func loadMore() async {
    guard hasMoreItems, !isLoadingMore, let current = state.value else { return }
    isLoadingMore = true
    defer { isLoadingMore = false }
    let newItems = try await repository.fetchMoreItems(search: search, offset: current.items.count)
    hasMoreItems = !newItems.isEmpty
    state = .loaded(HomeScreenData(items: current.items + newItems, priorities: current.priorities))
}
```

`HomeSplitView` triggers it from the last row's `.onAppear` — the standard "infinite
scroll" hook — and shows a footer `ProgressView` while `isLoadingMore`. A failed
`loadMore()` is an alert (`AlertService`), not `state = .failed(...)`, for the same reason
a failed delete is: the list already on screen loaded fine, only the next page didn't.

**Why a second method instead of a `page:`/`offset:` parameter on `fetchItems` itself**:
`fetchItems(search:)` staying page-less keeps its existing contract — "the current
complete-enough list to show, cached for offline" — unchanged for every other call site.
That matters because `ItemRepositoryImpl`'s SwiftData cache used to treat *every* fetch's
DTOs as the complete set and delete any cached row not present in them; a page's worth of
DTOs would make every other page's cached rows look stale. `fetchItems` still does that
prune (`upsert` + `pruneStale`); `fetchMoreItems` only `upsert`s, never prunes — safe to
call with a partial set, at the cost of no offline fallback for a failed load-more (a
documented, deliberate simplification, not an oversight).

One more knock-on effect worth knowing about if you copy this pattern: `fetchItem(id:)`
(used by `ItemDetailViewModel`) can no longer assume `fetchItems().first { $0.id == id }`
will find the item — that only searches the first page. `ItemRepositoryImpl.fetchItem(id:)`
checks the local SwiftData cache first instead (which holds every page ever fetched, via
`fetchMoreItems`'s upsert), falling back to a full fetch only if the cache misses.

## Localization

Every user-facing string is a `Domain/AppStrings.swift` symbol backed by a
`Resources/Localizable.xcstrings` entry (source language `en`) — add both together for any
new string, rather than a `String(localized: "...")` literal inline at the call site.

- **View code never changes.** `Text`, `Label`, `Button`, `TextField`, `Section`,
  `Picker`, `navigationTitle`, `ContentUnavailableView`, and `LabeledContent` all take
  either `LocalizedStringKey` or a plain `String` — `AppStrings.items` (a `String`) just
  resolves to the StringProtocol-taking overload of whichever initializer, displaying the
  already-localized text directly. No `Text(LocalizedStringKey("..."))` ceremony needed.
- **Domain and Presentation code can't skip localization by using a raw `String`.**
  `AppError.errorDescription` and `AddEditItemViewModel.navigationTitle` are plain
  `String`-returning properties, not SwiftUI `Text` calls, so they don't get Xcode's
  automatic compiler string-extraction — they call `AppStrings.xxx` explicitly instead.
- **Parameterized messages are functions, not string interpolation.** `AppStrings
  .fieldCannotBeEmpty(field)` builds `"%@ can't be empty."` via `String(format:)`, so the
  catalog holds one template entry regardless of what `field` is, instead of a
  new entry per distinct value interpolation would produce.
- **Item/Priority data is never localized** — `item.title`, `item.detail`,
  `priority.name`, and `viewModel.environment.rawValue` (`"Dev"`/`"QA"`/`"Prod"`, a
  developer-facing distinction, not end-user prose) are content or technical labels, not
  app chrome, and stay as plain interpolated `String`s passed straight to `Text`.

`Localizable.xcstrings` currently has only `en` (this template's source language) — add a
language in Xcode (select the catalog, use the Editor menu or the "+" in the Inspector) and
translate each entry's value when you actually need a second language; nothing else in the
code changes.

## Design tokens

`Colors.swift`/`Typography.swift`/`Icons.swift` (`Presentation/Shared/`) hold every
color/font/SF Symbol this template's chrome uses — same role as `Spacing.swift`: a named
constant instead of a `.foregroundStyle(.red)`/`.font(.title.bold())`/`"trash"` literal
repeated (or slightly misspelled between call sites) throughout the codebase. Rebranding
(swap the accent color, change the type scale, swap an icon) means editing one of these
three files, not grepping for every screen that happens to use `.title` or `"pencil"`.

```swift
enum Colors {
    static let accent = Color.accentColor
    static let destructive = Color.red
    static let success = Color.green
    static let warning = Color.orange
    static let secondaryText = Color.secondary
}

enum Typography {
    static let heroIcon = Font.system(size: 64)      // SplashView's app icon
    static let sectionIcon = Font.system(size: 48)    // SettingsView's About icon
    static let heading = Font.title.bold()            // SplashView, ItemDetailView
    static let subheading = Font.title2.bold()        // SettingsView's About title
    static let body = Font.body
    static let caption = Font.caption
}

enum Icons {
    static let appIcon = "app.fill"              // SplashView's hero icon
    static let aboutIcon = "app.badge.checkmark"  // SettingsView's About icon
    static let homeTab = "list.bullet"
    static let settingsTab = "gearshape"
    static let add = "plus"
    static let edit = "pencil"
    static let delete = "trash"
    static let emptyList = "tray"
    static let noSelection = "sidebar.left"
    static let failure = "exclamationmark.triangle"      // LoadFailureView's icon
    static let warning = "exclamationmark.triangle.fill"  // AlertContent's warning icon
    static let success = "checkmark.circle.fill"           // ToastContent's success icon
}
```

Deliberately *not* here: a full 8-step type scale, a wide brand palette, or an exhaustive
icon catalog with nothing using most of it — every token above backs a real call site today
(same reasoning as `Spacing`'s 3 sizes, not 8). Add a token when a new screen needs a
genuinely different color/style/icon, not speculatively.

`AlertCenterOverlay`'s `AlertTint -> Color` mapping reads from `Colors` too (`.destructive`
-> `Colors.destructive`, etc.) — so an alert's "destructive" icon and a form's
validation-error text (`AddEditItemView`'s `Text(message).foregroundStyle(Colors
.destructive)`) always match, without either file hardcoding `.red` independently.
`AlertContent`/`ToastContent`'s `icon: String?` field (`Domain/Services/AlertService.swift`)
takes a plain SF Symbol name — pass `Icons.warning`/`.success`/etc. from a call site rather
than a new string literal.

## Reusable form components

`ValidatedTextField` and `.buttonStyle(.primary/.secondary/.destructive)`
(`Presentation/Shared/`) are the two pieces `AddEditItemView` used to hand-roll — a bare
`TextField` with a form-wide error `Text` below the *whole* form (not scoped to the field it
was actually about), and ad hoc `.tint(...)`/`.fontWeight(...)` styling repeated at every
button call site. Reach for these on the next form instead of repeating either pattern:

```swift
ValidatedTextField(
    title: AppStrings.title,
    text: $viewModel.title,
    errorMessage: viewModel.validationError?.errorDescription
)
// axis: .vertical for a multi-line field (AddEditItemView's Detail field), same as TextField's own parameter

Button(AppStrings.save, action: save).buttonStyle(.primary)
Button(AppStrings.cancel, action: dismiss).buttonStyle(.secondary)
Button(AppStrings.delete, action: delete).buttonStyle(.destructive)
```

Both are built from `Colors`/`Typography`/`Spacing` (not their own literals), and
`AlertCenterOverlay`'s alert buttons use the same three `ButtonStyle`s — `AlertButtonRole`
(`.primary`/`.secondary`/`.destructive`, `Domain/Services/AlertService.swift`) maps directly
to `.buttonStyle(.primary/.secondary/.destructive)`, so an alert's buttons and a form's
buttons share one visual vocabulary instead of two independently-styled ones.

Deliberately *not* here: a full form-builder DSL, per-field validation rules, or a generic
`FormField<Value>` covering every input type (picker, toggle, date) — `ValidatedTextField`
covers exactly the shape `AddEditItemView` needed (`TextField` + inline error). Add a
sibling component (`ValidatedPicker`, `ValidatedToggle`, ...) when a real screen needs one,
following the same shape, rather than generalizing ahead of an actual second use.

## Alerts & toasts

`AlertService.showAlert`/`.showToast` render a custom dialog and bottom banner — not native
`.alert(...)`, which can't show an icon, can't align the message, and can't give a button
its own color/prominence. Inject `AlertService` through the initializer, same as
`ItemRepository`, and call the plain-string convenience form for the common case:

```swift
init(repository: ItemRepository, alertService: AlertService) { ... }
...
alertService.showAlert(title: AppStrings.couldntDeleteItem, message: error.localizedDescription)
alertService.showToast(AppStrings.itemSaved)
```

Reach for `AlertContent`/`ToastContent` (`Domain/Services/AlertService.swift`) directly when
you need more than that — an icon, extra buttons, a toast action:

```swift
alertService.showAlert(
    AlertContent(
        title: AppStrings.delete,
        message: "This can't be undone.",
        icon: "exclamationmark.triangle.fill",
        iconTint: .warning,
        buttons: [
            AlertButtonConfig(title: AppStrings.cancel, role: .secondary, action: {}),
            AlertButtonConfig(title: AppStrings.delete, role: .destructive, action: { viewModel.confirmDelete() })
        ]
    )
)

alertService.showToast(
    ToastContent(message: "Item Deleted", icon: "checkmark.circle.fill", tint: .success,
                 action: .init(title: "Undo", handler: { viewModel.undoDelete() }))
)
```

- `AlertButtonRole` (`.primary`/`.secondary`/`.destructive`) controls a button's visual
  weight and color — `.automatic` `buttonLayout` stacks vertically once there are more than
  2 buttons, matching native `.alert`'s own behavior; pass `.horizontal`/`.vertical` to
  override that for one alert.
- `AlertTint` (`.accent`/`.destructive`/`.success`/`.warning`/`.neutral`) is the "theme
  color" knob for an icon or toast — a bounded set of semantic choices, not an arbitrary
  `Color`, so it stays Domain-safe (see below) instead of turning into a full design-token
  system nobody asked for.
- `AlertTextAlignment` (`.leading`/`.center`/`.trailing`) controls the alert's title/message
  alignment.
- A toast's `duration` (default 2.5s) and `action` (a second, non-dismiss button) are both
  optional `ToastContent` fields.

`AppDependencies.makeHomeViewModel()`/`makeAddEditItemViewModel()` pass its own
`alertCenter`; a test passes `NoOpAlertService()` (discards both calls) or a small spy that
records them — see `HomeViewModelTests.deleteFailureShowsAnAlertAndKeepsTheListLoaded()` for
the pattern.

**Why `AlertContent`/`ToastContent` use `AlertTint`, not `Color`.** Domain imports only
`Foundation` (Architecture rule #4) — a `SwiftUI.Color`/`TextAlignment` field on a Domain
protocol's parameter type would break that. `AlertCenterOverlay` (Presentation) is the one
place that maps `AlertTint`/`AlertTextAlignment` to real SwiftUI values; everything upstream
of it, including the whole `AlertService` file, stays SwiftUI-free.

**Why the real implementation isn't `AlertServiceImpl`.** Every other service in this
template (`ReachabilityService`, `SecureStorageService`) has a real/mock split that varies
*by environment* — Dev gets a fake for convenience, QA/Prod get the real thing. Alerts don't
work that way: there's no dev-time reason to fake one, only to render it, so
`AppDependencies.alertCenter` is a single concrete `AlertCenter` instance used in every
environment — the same pattern as `NavigationCoordinator`, not `ReachabilityServiceImpl`.
`AlertCenter` is `@Observable`, and `AppContainerView` binds to it directly (via
`.alertCenterOverlay(_:)`) to render `activeAlert`/`activeToast` — the same reason
`HomeSplitView` binds to `NavigationCoordinator` directly instead of a protocol. Naming it
`AlertCenter` instead of `AlertServiceImpl` is deliberate, not just stylistic: the
`no_concrete_impl_outside_composition_root` rule (see "Architecture rules" below) would
otherwise fail the build on `Presentation/Shared/AlertCenterOverlay.swift` referencing it —
correctly so for a real `...RepositoryImpl`/`...ServiceImpl`, but wrong for presentation
state a root view is meant to own. Everywhere else, inject and call the `AlertService`
protocol — only `AppContainerView` (the app shell, composition-root-adjacent) and
`AlertCenterOverlay` itself touch `AlertCenter` concretely.

## Authentication

`AppContainerView` gates the whole app on it: signed out shows `LoginView`, signed in shows
`MainTabView`, decided by `AuthSessionStore.isAuthenticated`. The pieces, same shape as
every other feature in this template:

- **Domain**: `AuthSession` (`Domain/Models/`) — just `token` + `email`, not a full user
  profile; add a separate `User` model if a real app needs name/avatar/roles. `AuthRepository`
  (`Domain/Repositories/`) — `login(email:password:)`/`logout()`, the same protocol shape as
  `ItemRepository`.
- **Data**: `AuthRepositoryImpl` (real, calls `POST auth/login`/`auth/logout` via the shared
  `APIClient`) and `MockAuthRepositoryImpl` (Dev — accepts one fixed demo credential,
  `MockAuthRepositoryImpl.demoEmail`/`.demoPassword`, rejects anything else with the same
  `AppError` a real 401 would produce, so the "wrong password" path is demoable with no
  backend).
- **Presentation**: `LoginViewModel` + `LoginView` (`Presentation/Auth/`), built from
  `ValidatedTextField`/`.buttonStyle(.primary)` — see "Reusable form components". `LoginView`
  passes `isSecure: true` for the password field.

**`AuthSessionStore` (`Core/Coordinator/AuthSessionStore.swift`), not `LoginViewModel`,
owns whether you're signed in.** Same reasoning as `AlertCenter`/`NavigationCoordinator`:
it's live, `@Observable` presentation state a root view (`AppContainerView`) binds to
directly, not a swappable Data-layer implementation — so `LoginViewModel` depends only on
the `AuthRepository` protocol and returns a token on success; `LoginView` is the one that
calls `authSessionStore.signIn(token:)` with it, the same way `AddEditItemView` (not
`AddEditItemViewModel`) calls `onSaved(saved)`. `AuthSessionStore` itself doesn't touch the
network — it only tracks/persists whether a token exists, reading/writing it through
`SecureStorageService` (`SecureStorageKey.authToken` — the same key
`AuthHeaderInterceptor` already reads on every authenticated request, so nothing in the
networking layer changes when you swap `MockAuthRepositoryImpl` for the real one).
`SettingsView`'s "Log Out" button calls `authSessionStore.signOut()` directly, the same way
it already calls `coordinator.push(.about)` — both are concrete, View-bound state, not
something a ViewModel mediates.

`demoCredentialsHint` (shown under the Log In button, Dev only) is computed by
`AppDependencies.makeLoginViewModel()` — the composition root, the only place allowed to
reference `MockAuthRepositoryImpl` — and passed into `LoginViewModel` as a plain `String?`,
rather than `LoginViewModel` importing that concrete Data-layer type itself to read
`.demoEmail`/`.demoPassword` directly.

## Deep linking

The `apptemplate://` URL scheme (registered in `project.yml`'s `target.info.properties` —
see `Config/` in the folder structure above) routes through one place:
`NavigationCoordinator.handle(url:)`, called from `AppContainerView`'s `.onOpenURL`:

```swift
xcrun simctl openurl booted "apptemplate://items/42"      // Home tab, item 42 selected
xcrun simctl openurl booted "apptemplate://settings"       // Settings tab
xcrun simctl openurl booted "apptemplate://settings/about" // Settings tab, About pushed
```

**Works before login, for free.** `NavigationCoordinator` is one instance `AppDependencies`
builds once and both `LoginView`'s post-auth `MainTabView` and (indirectly) `AppContainerView`
read from — so a link opened while `LoginView` is still showing just sets
`selectedTab`/`selectedItemID` on that instance and sits there; once the user logs in and
`MainTabView` mounts, `TabView(selection: $coordinator.selectedTab)` and `HomeSplitView`'s
`coordinator.selectedItemID` binding already reflect it. No pending-deep-link queue needed —
verified live: open an `items/` link on the login screen, log in, land straight on that
item's detail view.

`AppTab` (`Core/Coordinator/NavigationCoordinator.swift`) — `.home`/`.settings` — exists
specifically so `MainTabView`'s `TabView` has a `selection:` a deep link (or anything else)
can set programmatically; without it, `TabView` manages its own selection privately and
nothing outside the view can switch tabs.

**Universal links reuse the same seam.** `.onOpenURL` fires for `https://` universal links
too, once an app adds the Associated Domains entitlement and hosts an
`apple-app-site-association` file — both require a real domain to set up and verify, so
they're not included here (same reasoning as the "What's deliberately not here" section).
`NavigationCoordinator.handle(url:)` doesn't need to change at all when that's added: it
already works off `URL.host`/`.pathComponents`, which mean the same thing for
`https://yourapp.com/items/42` as for `apptemplate://items/42`.

## Architecture notes

- **`AppError`** (`Domain/AppError.swift`) is the one error vocabulary every layer
  throws — network/persistence/validation/configuration — so ViewModels switch on one
  type instead of learning what each dependency happens to throw. `EntityMapper` is the
  DTO-shape/persistence-entity-shape equivalent — see "Persistence".
