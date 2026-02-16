import Vapor

/// Sends Podping notifications when a podcast feed is updated.
///
/// Podping is the podcast industry's notification system. Instead of aggregators
/// polling thousands of feeds, hosting platforms send a single notification
/// when a feed changes.
///
/// ```swift
/// let notifier = PodpingNotifier(
///     client: req.client,
///     endpoint: "https://podping.cloud",
///     authToken: "your-auth-token"
/// )
/// try await notifier.notify(feedURL: "https://example.com/feed.xml", reason: .update)
/// ```
///
/// For testing or self-hosted Podping nodes, provide a custom endpoint URL.
public struct PodpingNotifier: Sendable {

    /// The Podping server endpoint (e.g., `https://podping.cloud`).
    private let endpoint: String

    /// The authorization token for the Podping server.
    private let authToken: String?

    /// The Vapor HTTP client used for sending requests.
    private let client: any Client

    /// Creates a new Podping notifier.
    ///
    /// - Parameters:
    ///   - client: Vapor HTTP client (typically `req.client` or `app.client`).
    ///   - endpoint: Podping server URL. Defaults to `"https://podping.cloud"`.
    ///   - authToken: Authorization token. `nil` for unauthenticated requests (local testing).
    public init(
        client: any Client,
        endpoint: String = "https://podping.cloud",
        authToken: String? = nil
    ) {
        self.client = client
        self.endpoint = endpoint
        self.authToken = authToken
    }

    /// Sends a Podping notification for a feed update.
    ///
    /// - Parameters:
    ///   - feedURL: The URL of the podcast feed that was updated.
    ///   - reason: The reason for the notification. Defaults to `.update`.
    ///   - medium: The type of media. Defaults to `.podcast`.
    /// - Throws: `PodpingError` if the notification fails.
    public func notify(
        feedURL: String,
        reason: PodpingReason = .update,
        medium: PodpingMedium = .podcast
    ) async throws {
        let urlString = "\(endpoint)/?url=\(feedURL)&reason=\(reason.rawValue)&medium=\(medium.rawValue)"

        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw PodpingError.invalidEndpoint(endpoint)
        }

        let uri = URI(string: encoded)
        var headers = HTTPHeaders()

        if let authToken {
            headers.add(name: .authorization, value: "Bearer \(authToken)")
        }

        let response = try await client.get(uri, headers: headers)

        guard (200..<300).contains(response.status.code) else {
            throw PodpingError.serverError(UInt(response.status.code))
        }
    }
}

/// Reason for a Podping notification.
public enum PodpingReason: String, Codable, Sendable, CaseIterable {
    /// A feed was updated (new episode, changed metadata).
    case update
    /// A livestream has started.
    case live
    /// A livestream has ended.
    case liveEnd
}

/// Media type for a Podping notification.
public enum PodpingMedium: String, Codable, Sendable, CaseIterable {
    case podcast
    case music
    case video
    case film
    case audiobook
    case newsletter
    case blog
}

/// Errors from Podping notification requests.
public enum PodpingError: Error, Sendable, Equatable {
    /// The Podping server returned an error status code.
    case serverError(UInt)
    /// The endpoint URL could not be constructed.
    case invalidEndpoint(String)
}
