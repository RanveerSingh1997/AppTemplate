import Foundation

struct LoginRequestDTO: Encodable, Sendable {
    let email: String
    let password: String
}

struct AuthResponseDTO: Decodable, Sendable {
    let token: String
    let email: String
}

extension AuthResponseDTO {
    var asDomain: AuthSession { AuthSession(token: token, email: email) }
}
