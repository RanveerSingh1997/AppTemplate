import Foundation

/// A best-effort guess at how your API shapes error bodies. Most JSON APIs put a
/// human-readable message under one of these keys — adjust to match your actual backend;
/// this is the one place that needs to change, not every call site.
struct APIErrorResponse: Decodable {
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case message, error, errorMessage, detail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .error)
            ?? container.decodeIfPresent(String.self, forKey: .errorMessage)
            ?? container.decodeIfPresent(String.self, forKey: .detail)
    }
}
