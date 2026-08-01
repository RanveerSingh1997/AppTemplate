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
    // Real in every environment, same as `coordinator` — there's no dev-time reason to
    // fake an alert, only to render one. See `AlertCenter`'s doc comment for why it's
    // exposed as this concrete type rather than through the `AlertService` protocol here.
    let alertCenter = AlertCenter()
    // Real in every environment too — whether you're signed in isn't a dev-vs-prod
    // concern. Constructed after the `switch` below, once `secureStorageService` exists.
    let authSessionStore: AuthSessionStore

    // Cross-cutting seams: built and available via AppDependencies, but not yet consumed
    // by any feature. Wire one in (pass it into a repository's init, same as `apiClient`)
    // when a concrete feature needs it — don't reach for `.shared` instead.
    let secureStorageService: SecureStorageService
    let reachabilityService: ReachabilityService
    let logger: EventLogger

    private let itemRepository: ItemRepository
    private let priorityRepository: PriorityRepository
    private let authRepository: AuthRepository

    // A hardcoded, compile-time-valid URL, only ever reached if AppConfiguration.apiBaseURL()
    // itself fails — i.e. a broken xcconfig, not a runtime condition to design around.
    private static let fallbackBaseURL = URL(string: "https://dev-api.example.com")!

    init() {
        environment = .current
        let (container, error) = PersistenceFactory.makeContainer()
        modelContainer = container
        startupError = error

        switch environment {
        case .dev:
            // No backend/Keychain friction needed to run the template out of the box.
            itemRepository = MockItemRepositoryImpl()
            priorityRepository = MockPriorityRepositoryImpl()
            authRepository = MockAuthRepositoryImpl()
            secureStorageService = InMemorySecureStorageService()
            reachabilityService = MockReachabilityService()
            logger = ConsoleEventLogger()
        case .qa, .prod:
            let baseURL = (try? AppConfiguration.apiBaseURL()) ?? AppDependencies.fallbackBaseURL
            let secureStorage = KeychainSecureStorageService()
            secureStorageService = secureStorage
            let consoleLogger = ConsoleEventLogger()
            logger = consoleLogger

            // Reads whatever an auth feature has stored under `.authTokenKey` and attaches
            // it as `Authorization: Bearer <token>` to every request. Before login this
            // just returns nil, so requests go out unauthenticated — nothing to wire up
            // differently once auth exists, since this reads live on every request.
            let authInterceptor = AuthHeaderInterceptor {
                guard case .success(let token) = secureStorage.get(forKey: SecureStorageKey.authToken) else {
                    return nil
                }
                return token
            }

            // Shared by every repository below — one client, one set of interceptors,
            // instead of a fresh URLSessionAPIClient (and its own interceptor stack) per
            // repository.
            let apiClient = URLSessionAPIClient(
                baseURL: baseURL,
                interceptors: [
                    CorrelationIDInterceptor(),
                    authInterceptor,
                    LoggingInterceptor(logger: consoleLogger)
                ],
                // No auth flow yet, so no refresh action exists to call on a 401 —
                // add one (e.g. calling an AuthRepository's refresh) once you have one.
                authTokenRefresher: nil
                // retryPolicy: .default (GET retried twice on 5xx/timeout)
                // pinnedPublicKeyHashes: [] (see PinnedCertificateValidator to enable)
            )

            itemRepository = ItemRepositoryImpl(apiClient: apiClient, modelContext: container.mainContext)
            priorityRepository = PriorityRepositoryImpl(apiClient: apiClient)
            authRepository = AuthRepositoryImpl(apiClient: apiClient)
            reachabilityService = ReachabilityServiceImpl()
        }

        authSessionStore = AuthSessionStore(secureStorageService: secureStorageService)
    }

    // MARK: - View model factories

    func makeSplashViewModel() -> SplashViewModel {
        SplashViewModel()
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(repository: itemRepository, priorityRepository: priorityRepository, alertService: alertCenter)
    }

    func makeItemDetailViewModel(itemID: String) -> ItemDetailViewModel {
        ItemDetailViewModel(itemID: itemID, repository: itemRepository)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(environment: environment)
    }

    func makeLoginViewModel() -> LoginViewModel {
        let demoCredentialsHint: String?
        switch environment {
        case .dev:
            demoCredentialsHint = "Demo: \(MockAuthRepositoryImpl.demoEmail) / \(MockAuthRepositoryImpl.demoPassword)"
        case .qa, .prod:
            demoCredentialsHint = nil
        }
        return LoginViewModel(authRepository: authRepository, demoCredentialsHint: demoCredentialsHint)
    }

    func makeAddEditItemViewModel(route: ItemFormRoute) -> AddEditItemViewModel {
        let mode: FormMode<Item>
        switch route {
        case .create: mode = .create
        case .edit(let item): mode = .edit(item)
        }
        return AddEditItemViewModel(
            mode: mode,
            repository: itemRepository,
            priorityRepository: priorityRepository,
            alertService: alertCenter
        )
    }
}
