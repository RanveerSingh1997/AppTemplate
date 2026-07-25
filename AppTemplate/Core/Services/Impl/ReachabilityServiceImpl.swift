import Network

/// Wraps `NWPathMonitor`, exposing a snapshot of the current path rather than a
/// continuous stream — enough for "check before this request" use, not a live UI banner
/// (that only needs the same path, observed via `pathUpdateHandler`, if you add one).
final class ReachabilityServiceImpl: ReachabilityService, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ReachabilityServiceImpl")

    init() {
        monitor.start(queue: queue)
    }

    func isConnected() async -> Bool {
        monitor.currentPath.status == .satisfied
    }

    func connectionType() async -> ConnectionType {
        let path = monitor.currentPath
        guard path.status == .satisfied else { return .none }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        return .other
    }

    deinit {
        monitor.cancel()
    }
}
