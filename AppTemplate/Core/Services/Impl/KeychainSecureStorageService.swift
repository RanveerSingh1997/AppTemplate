import Foundation
import Security

/// Keychain-backed secure storage. `kSecAttrAccessible` is `afterFirstUnlock` so background
/// refresh/sync work (which may run before the user unlocks the device this boot) can still
/// read stored values.
struct KeychainSecureStorageService: SecureStorageService {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "AppTemplate") {
        self.service = service
    }

    func set(_ value: String, forKey key: String) -> Result<Void, AppError> {
        guard let data = value.data(using: .utf8) else {
            return .failure(.unknown("Could not encode value for keychain key \(key)."))
        }
        _ = delete(forKey: key) // clear any existing value first so SecItemAdd doesn't fail with errSecDuplicateItem

        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            return .failure(.persistence(.saveFailed))
        }
        return .success(())
    }

    func get(forKey key: String) -> Result<String?, AppError> {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                return .success(nil)
            }
            return .success(value)
        case errSecItemNotFound:
            return .success(nil)
        default:
            return .failure(.persistence(.fetchFailed))
        }
    }

    func delete(forKey key: String) -> Result<Void, AppError> {
        let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return .failure(.persistence(.saveFailed))
        }
        return .success(())
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
    }
}
