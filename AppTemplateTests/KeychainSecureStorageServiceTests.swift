@testable import AppTemplate
import Foundation
import Testing

/// Runs against the real Keychain (the Simulator has one; no entitlements needed for a
/// plain `kSecClassGenericPassword` item like this uses) rather than a fake — the point is
/// verifying `SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete` actually behave the way
/// `KeychainSecureStorageService` assumes, not just that its own Swift logic is internally
/// consistent. Each test uses its own unique `service` string, so tests can't collide with
/// each other or with leftover state from a previous run.
struct KeychainSecureStorageServiceTests {
    private func makeService() -> KeychainSecureStorageService {
        KeychainSecureStorageService(service: "com.apptemplate.tests.\(UUID().uuidString)")
    }

    @Test
    func setThenGetReturnsTheStoredValue() {
        let service = makeService()

        #expect(service.set("secret", forKey: "token").isSuccess)
        #expect((try? service.get(forKey: "token").get()) == "secret")
    }

    @Test
    func getReturnsNilForAKeyThatWasNeverSet() {
        let service = makeService()
        #expect((try? service.get(forKey: "missing").get()) == nil)
    }

    @Test
    func setOverwritesAnExistingValueInsteadOfFailing() {
        let service = makeService()

        #expect(service.set("first", forKey: "token").isSuccess)
        #expect(service.set("second", forKey: "token").isSuccess)

        #expect((try? service.get(forKey: "token").get()) == "second")
    }

    @Test
    func deleteRemovesTheValue() {
        let service = makeService()
        _ = service.set("secret", forKey: "token")

        #expect(service.delete(forKey: "token").isSuccess)

        #expect((try? service.get(forKey: "token").get()) == nil)
    }

    @Test
    func deletingAKeyThatWasNeverSetStillSucceeds() {
        let service = makeService()
        #expect(service.delete(forKey: "missing").isSuccess)
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
