import Foundation

/// In-memory stand-in for `KeychainSecureStorageService` — used in development/tests so
/// no Keychain entitlement or simulator quirk gets in the way of running the app.
final class InMemorySecureStorageService: SecureStorageService, @unchecked Sendable {
    private var storage: [String: String] = [:]
    private let lock = NSLock()

    func set(_ value: String, forKey key: String) -> Result<Void, AppError> {
        lock.lock(); defer { lock.unlock() }
        storage[key] = value
        return .success(())
    }

    func get(forKey key: String) -> Result<String?, AppError> {
        lock.lock(); defer { lock.unlock() }
        return .success(storage[key])
    }

    func delete(forKey key: String) -> Result<Void, AppError> {
        lock.lock(); defer { lock.unlock() }
        storage.removeValue(forKey: key)
        return .success(())
    }
}
