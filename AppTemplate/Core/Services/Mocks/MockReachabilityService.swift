import Foundation

/// Always reports connected — swap `isConnectedOverride`/`connectionTypeOverride` in tests
/// that need to simulate being offline.
final class MockReachabilityService: ReachabilityService, @unchecked Sendable {
    var isConnectedOverride = true
    var connectionTypeOverride: ConnectionType = .wifi

    func isConnected() async -> Bool { isConnectedOverride }
    func connectionType() async -> ConnectionType { connectionTypeOverride }
}
