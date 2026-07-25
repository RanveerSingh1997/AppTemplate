import Foundation

enum ConnectionType: Sendable {
    case wifi
    case cellular
    case ethernet
    case other
    case none
}

/// Network connectivity check. Not consumed anywhere yet — this is the seam a
/// repository would check before hitting the network, or an offline banner would observe.
protocol ReachabilityService: Sendable {
    func isConnected() async -> Bool
    func connectionType() async -> ConnectionType
}
