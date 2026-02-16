import Foundation

/// A message exchanged over a Podping WebSocket connection.
///
/// Messages flow in both directions:
/// - **Server → Client**: ``MessageKind/welcome``, ``MessageKind/notification``,
///   ``MessageKind/subscribed``
/// - **Client → Server**: ``MessageKind/subscribe``, ``MessageKind/unsubscribe``
///
/// ```swift
/// // Notification sent when a feed is updated
/// let message = PodpingMessage(
///     kind: .notification,
///     feedURL: "https://example.com/feed.xml",
///     reason: .update,
///     medium: .podcast
/// )
/// let json = try JSONEncoder().encode(message)
/// ```
public struct PodpingMessage: Codable, Sendable, Equatable {

    /// The kind of WebSocket message.
    public enum MessageKind: String, Codable, Sendable, Equatable {
        /// Server → Client: sent immediately after connection is established.
        case welcome
        /// Server → Client: a feed was updated.
        case notification
        /// Server → Client: subscription confirmation.
        case subscribed
        /// Client → Server: subscribe to specific feed URLs.
        case subscribe
        /// Client → Server: unsubscribe from specific feed URLs.
        case unsubscribe
    }

    /// The kind of message.
    public let kind: MessageKind

    /// The feed URL (for notification messages).
    public let feedURL: String?

    /// Feed URLs to subscribe/unsubscribe (for subscribe/unsubscribe messages).
    public let feedURLs: [String]?

    /// The notification reason (for notification messages).
    public let reason: PodpingReason?

    /// The media type (for notification messages).
    public let medium: PodpingMedium?

    /// ISO 8601 timestamp (for notification messages).
    public let timestamp: String?

    /// Server message (for welcome and subscribed messages).
    public let message: String?

    /// Creates a new Podping WebSocket message.
    public init(
        kind: MessageKind,
        feedURL: String? = nil,
        feedURLs: [String]? = nil,
        reason: PodpingReason? = nil,
        medium: PodpingMedium? = nil,
        timestamp: String? = nil,
        message: String? = nil
    ) {
        self.kind = kind
        self.feedURL = feedURL
        self.feedURLs = feedURLs
        self.reason = reason
        self.medium = medium
        self.timestamp = timestamp
        self.message = message
    }

    /// Creates a notification message for a feed update.
    ///
    /// - Parameters:
    ///   - feedURL: The updated feed URL.
    ///   - reason: The update reason.
    ///   - medium: The media type.
    /// - Returns: A notification message with the current timestamp.
    public static func notification(
        feedURL: String,
        reason: PodpingReason = .update,
        medium: PodpingMedium = .podcast
    ) -> PodpingMessage {
        let formatter = ISO8601DateFormatter()
        return PodpingMessage(
            kind: .notification,
            feedURL: feedURL,
            reason: reason,
            medium: medium,
            timestamp: formatter.string(from: Date())
        )
    }

    /// Creates a welcome message sent to newly connected clients.
    public static func welcome() -> PodpingMessage {
        PodpingMessage(
            kind: .welcome,
            message: "Connected to Podping WebSocket"
        )
    }

    /// Creates a subscription confirmation message.
    ///
    /// - Parameter feedURLs: The feed URLs the client is now subscribed to.
    ///   Empty array means subscribed to all feeds.
    public static func subscribed(feedURLs: [String]) -> PodpingMessage {
        PodpingMessage(
            kind: .subscribed,
            feedURLs: feedURLs,
            message: feedURLs.isEmpty
                ? "Subscribed to all feeds"
                : "Subscribed to \(feedURLs.count) feed(s)"
        )
    }
}
