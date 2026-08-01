import Foundation

/// Every backend route's path, HTTP method, and query parameters, defined once — a
/// repository method never picks a verb or builds a path/query separately, so it can't
/// pass the wrong verb for a given route. Add a case per route, with typed parameters (a
/// `String?` for `search`, not a caller-assembled `URLQueryItem`); split into per-feature
/// endpoint enums (`ItemAPIEndpoint`, `AccountAPIEndpoint`, ...) only once a single file
/// actually gets crowded — one small file beats speculative per-feature files for the one
/// feature this template ships.
enum APIEndpoint {
    case fetchItems(search: String?, offset: Int = 0)
    case createItem
    case updateItem(id: String)
    case deleteItem(id: String)
    /// Reference data for `AddEditItemView`'s priority picker — its own case rather than
    /// piggybacking on an `items`-shaped route, since it's a different resource entirely.
    case fetchPriorities
    case login
    case logout

    var path: String {
        switch self {
        case .fetchItems, .createItem:
            return "items"
        case .updateItem(let id), .deleteItem(let id):
            return "items/\(id)"
        case .fetchPriorities:
            return "priorities"
        case .login:
            return "auth/login"
        case .logout:
            return "auth/logout"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .fetchItems, .fetchPriorities:
            return .get
        case .createItem, .login, .logout:
            return .post
        case .updateItem:
            return .put
        case .deleteItem:
            return .delete
        }
    }

    var queryItems: [URLQueryItem] {
        guard case .fetchItems(let search, let offset) = self else { return [] }
        var items: [URLQueryItem] = []
        if let search, !search.isEmpty {
            items.append(URLQueryItem(name: "search", value: search))
        }
        if offset > 0 {
            items.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        return items
    }

    /// Classifies a 404 by path pattern rather than by typed case — logging only ever sees
    /// `URLRequest.url?.path` (which has a leading "/", unlike `path` above), never the
    /// `APIEndpoint` case that built it, so this is the fallback form (mirrors `path`'s own
    /// single-item-route shape: `items/{id}`). Acting on an id that's already gone
    /// (update/delete) is a normal race, not a bug; keeping this true for those paths stops
    /// it from reading as an error on a dashboard.
    static func isExpectedNotFound(forPath path: String) -> Bool {
        let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return normalized.hasPrefix("items/")
    }
}
