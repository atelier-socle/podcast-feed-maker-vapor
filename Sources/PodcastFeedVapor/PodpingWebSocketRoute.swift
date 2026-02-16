import Vapor

extension Application {
    /// The Podping WebSocket manager for this application.
    ///
    /// Used to broadcast feed update notifications to connected WebSocket clients.
    ///
    /// ```swift
    /// // Broadcast a feed update
    /// await app.podpingWebSocketManager.broadcast(
    ///     feedURL: "https://example.com/feed.xml",
    ///     reason: .update
    /// )
    /// ```
    public var podpingWebSocketManager: PodpingWebSocketManager {
        get {
            if let existing = self.storage[PodpingWebSocketManagerKey.self] {
                return existing
            }
            let manager = PodpingWebSocketManager()
            self.storage[PodpingWebSocketManagerKey.self] = manager
            return manager
        }
        set { self.storage[PodpingWebSocketManagerKey.self] = newValue }
    }

    private struct PodpingWebSocketManagerKey: StorageKey {
        typealias Value = PodpingWebSocketManager
    }
}

extension Application {
    /// Registers a WebSocket endpoint for real-time Podping notifications.
    ///
    /// Clients connect via WebSocket and receive JSON notifications when
    /// feeds are updated via ``PodpingWebSocketManager/broadcast(feedURL:reason:medium:)``.
    ///
    /// ```swift
    /// // Register endpoint at ws://host/podping
    /// app.podpingWebSocket("podping")
    ///
    /// // Later, broadcast a feed update
    /// await app.podpingWebSocketManager.broadcast(
    ///     feedURL: "https://example.com/feed.xml"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - path: One or more path components for the WebSocket route.
    ///     Defaults to `"podping"`.
    ///   - manager: The WebSocket manager to use. Defaults to the
    ///     application's shared ``podpingWebSocketManager``.
    public func podpingWebSocket(
        _ path: PathComponent...,
        manager: PodpingWebSocketManager? = nil
    ) {
        let resolvedPath = path.isEmpty ? [PathComponent("podping")] : path
        let resolvedManager = manager ?? self.podpingWebSocketManager

        self.webSocket(resolvedPath) { _, ws async in
            await resolvedManager.addConnection(ws)
        }
    }
}
