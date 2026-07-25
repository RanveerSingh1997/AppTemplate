import Foundation
import SwiftData

/// Composition root. Builds the real or mock implementation for each dependency exactly
/// once here, and exposes typed `make*ViewModel()` factories — Views/ViewModels never see
/// concrete Data-layer types, and there's no central switch/cast to keep in sync as you
/// add screens (compare to a router that downcasts a type-erased view model per screen).
@MainActor
final class AppDependencies {
    let environment: AppEnvironment
    let modelContainer: ModelContainer
    let startupError: AppError?
    let coordinator = NavigationCoordinator()

    // Cross-cutting seams: built and available via AppDependencies, but not yet consumed
    // by any feature. Wire one in (pass it into a repository's init, same as `apiClient`)
    // when a concrete feature needs it — don't reach for `.shared` instead.
    let secureStorageService: SecureStorageService
    let reachabilityService: ReachabilityService
    let logger: EventLogger

    private let itemRepository: ItemRepository

    // A hardcoded, compile-time-valid URL, only ever reached if AppConfiguration.apiBaseURL()
    // itself fails — i.e. a broken xcconfig, not a runtime condition to design around.
    private static let fallbackBaseURL = URL(string: "https://dev-api.example.com")! // swiftlint:disable:this force_unwrapping

    init() {
        environment = .current
        let (container, error) = PersistenceFactory.makeContainer()
        modelContainer = container
        startupError = error

        switch environment {
        case .dev:
            // No backend/Keychain friction needed to run the template out of the box.
            itemRepository = MockItemRepositoryImpl()
            secureStorageService = InMemorySecureStorageService()
            reachabilityService = MockReachabilityService()
            logger = ConsoleEventLogger()
        case .qa, .prod:
            let baseURL = (try? AppConfiguration.apiBaseURL()) ?? AppDependencies.fallbackBaseURL
            let secureStorage = KeychainSecureStorageService()
            secureStorageService = secureStorage

            // Reads whatever an auth feature has stored under `.authTokenKey` and attaches
            // it as `Authorization: Bearer <token>` to every request. Before login this
            // just returns nil, so requests go out unauthenticated — nothing to wire up
            // differently once auth exists, since this reads live on every request.
            let authInterceptor = AuthHeaderInterceptor {
                guard case .success(let token) = secureStorage.get(forKey: SecureStorageKey.authToken) else { return nil }
                return token
            }

            itemRepository = ItemRepositoryImpl(
                apiClient: URLSessionAPIClient(
                    baseURL: baseURL,
                    interceptors: [authInterceptor],
                    // No auth flow yet, so no refresh action exists to call on a 401 —
                    // add one (e.g. calling an AuthRepository's refresh) once you have one.
                    authTokenRefresher: nil
                ),
                modelContext: container.mainContext
            )
            reachabilityService = ReachabilityServiceImpl()
            logger = ConsoleEventLogger()
        }
    }

    // MARK: - View model factories

    func makeSplashViewModel() -> SplashViewModel {
        SplashViewModel()
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(repository: itemRepository)
    }

    func makeItemDetailViewModel(itemID: String) -> ItemDetailViewModel {
        ItemDetailViewModel(itemID: itemID, repository: itemRepository)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(environment: environment)
    }

    func makeAddEditItemViewModel(route: ItemFormRoute) -> AddEditItemViewModel {
        let mode: AddEditItemViewModel.Mode
        switch route {
        case .create: mode = .create
        case .edit(let item): mode = .edit(item)
        }
        return AddEditItemViewModel(mode: mode, repository: itemRepository)
    }
}
