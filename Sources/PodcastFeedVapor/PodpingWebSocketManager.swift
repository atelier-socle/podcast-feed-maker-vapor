// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Atelier Socle SAS
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Vapor

/// Manages WebSocket connections for real-time Podping notifications.
///
/// Clients connect and optionally subscribe to specific feed URLs.
/// When ``broadcast(feedURL:reason:medium:)`` is called, the manager
/// sends a JSON notification to all matching connected clients.
///
/// ```swift
/// let manager = PodpingWebSocketManager()
///
/// // Register a WebSocket endpoint
/// app.podpingWebSocket("podping")
///
/// // Broadcast a feed update to all connected clients
/// await manager.broadcast(
///     feedURL: "https://example.com/feed.xml",
///     reason: .update,
///     medium: .podcast
/// )
/// ```
///
/// Clients subscribed to specific feeds only receive matching notifications.
/// Clients with no subscriptions (default) receive all notifications.
public actor PodpingWebSocketManager {

    /// A connected WebSocket client with optional feed subscriptions.
    struct Connection: Sendable {
        let id: UUID
        let ws: WebSocket
        /// Feed URLs this client wants notifications for.
        /// Empty means "all feeds".
        var subscribedFeeds: Set<String>
    }

    /// Active connections indexed by UUID.
    private var connections: [UUID: Connection] = [:]

    /// JSON encoder for outgoing messages.
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    /// Creates a new WebSocket manager.
    public init() {}

    /// The number of currently connected clients.
    public var connectionCount: Int {
        connections.count
    }

    /// Registers a new WebSocket connection.
    ///
    /// Sends a welcome message and sets up close/text handlers.
    ///
    /// - Parameter ws: The WebSocket connection to register.
    /// - Returns: The UUID assigned to this connection.
    @discardableResult
    public func addConnection(_ ws: WebSocket) -> UUID {
        let id = UUID()
        connections[id] = Connection(id: id, ws: ws, subscribedFeeds: [])

        // Send welcome message
        if let data = try? encoder.encode(PodpingMessage.welcome()),
            let string = String(data: data, encoding: .utf8)
        {
            ws.send(string)
        }

        // Handle incoming text messages (subscribe/unsubscribe)
        ws.onText { [weak self] _, text in
            guard let self else { return }
            await self.handleMessage(text, connectionID: id)
        }

        // Clean up on close
        ws.onClose.whenComplete { [weak self] _ in
            guard let self else { return }
            Task {
                await self.removeConnection(id)
            }
        }

        return id
    }

    /// Removes a connection by ID.
    ///
    /// - Parameter id: The connection UUID to remove.
    public func removeConnection(_ id: UUID) {
        connections.removeValue(forKey: id)
    }

    /// Updates the subscription for a connection.
    ///
    /// - Parameters:
    ///   - id: The connection UUID.
    ///   - feedURLs: Feed URLs to subscribe to. Empty array means "all feeds".
    public func subscribe(connectionID id: UUID, feedURLs: [String]) {
        guard var connection = connections[id] else { return }
        connection.subscribedFeeds = Set(feedURLs)
        connections[id] = connection

        // Send confirmation
        let confirmation = PodpingMessage.subscribed(feedURLs: feedURLs)
        if let data = try? encoder.encode(confirmation),
            let string = String(data: data, encoding: .utf8)
        {
            connection.ws.send(string)
        }
    }

    /// Removes specific feed URLs from a connection's subscription.
    ///
    /// - Parameters:
    ///   - id: The connection UUID.
    ///   - feedURLs: Feed URLs to unsubscribe from.
    public func unsubscribe(connectionID id: UUID, feedURLs: [String]) {
        guard var connection = connections[id] else { return }
        connection.subscribedFeeds.subtract(feedURLs)
        connections[id] = connection

        let remaining = Array(connection.subscribedFeeds)
        let confirmation = PodpingMessage.subscribed(feedURLs: remaining)
        if let data = try? encoder.encode(confirmation),
            let string = String(data: data, encoding: .utf8)
        {
            connection.ws.send(string)
        }
    }

    /// Broadcasts a feed update notification to all matching connected clients.
    ///
    /// Clients with no subscriptions receive all notifications.
    /// Clients subscribed to specific feeds only receive matching ones.
    ///
    /// - Parameters:
    ///   - feedURL: The URL of the updated feed.
    ///   - reason: The update reason.
    ///   - medium: The media type.
    public func broadcast(
        feedURL: String,
        reason: PodpingReason = .update,
        medium: PodpingMedium = .podcast
    ) {
        let notification = PodpingMessage.notification(
            feedURL: feedURL,
            reason: reason,
            medium: medium
        )

        guard let data = try? encoder.encode(notification),
            let string = String(data: data, encoding: .utf8)
        else { return }

        for connection in connections.values {
            // Send to clients with no filter OR clients subscribed to this feed
            if connection.subscribedFeeds.isEmpty || connection.subscribedFeeds.contains(feedURL) {
                connection.ws.send(string)
            }
        }
    }

    /// Returns the set of subscribed feed URLs for a connection.
    ///
    /// - Parameter id: The connection UUID.
    /// - Returns: The subscribed feed URLs, or `nil` if the connection doesn't exist.
    public func subscriptions(for id: UUID) -> Set<String>? {
        connections[id]?.subscribedFeeds
    }

    // MARK: - Private

    /// Handles an incoming text message from a client.
    func handleMessage(_ text: String, connectionID id: UUID) {
        guard let data = text.data(using: .utf8),
            let message = try? JSONDecoder().decode(PodpingMessage.self, from: data)
        else {
            return  // Silently ignore malformed messages
        }

        switch message.kind {
        case .subscribe:
            if let feedURLs = message.feedURLs {
                subscribe(connectionID: id, feedURLs: feedURLs)
            }
        case .unsubscribe:
            if let feedURLs = message.feedURLs {
                unsubscribe(connectionID: id, feedURLs: feedURLs)
            }
        case .welcome, .notification, .subscribed:
            break  // Server-originated messages — ignore from client
        }
    }
}
