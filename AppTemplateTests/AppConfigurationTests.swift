@testable import AppTemplate
import Testing

struct AppConfigurationTests {
    @Test
    func parseAPIBaseURLUnescapesTheXcconfigCommentEscape() throws {
        let url = try AppConfiguration.parseAPIBaseURL("https:\\/\\/dev-api.example.com")
        #expect(url.scheme == "https")
        #expect(url.host == "dev-api.example.com")
    }

    @Test
    func parseAPIBaseURLAcceptsAnAlreadyUnescapedURL() throws {
        let url = try AppConfiguration.parseAPIBaseURL("https://dev-api.example.com")
        #expect(url.host == "dev-api.example.com")
    }

    @Test
    func parseAPIBaseURLThrowsForGarbageInput() {
        #expect(throws: AppError.self) {
            _ = try AppConfiguration.parseAPIBaseURL("not a url")
        }
    }
}
