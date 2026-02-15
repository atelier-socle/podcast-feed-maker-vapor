import PodcastFeedMaker
import Vapor

/// Encodes a `PodcastFeed` into an HTTP response with RSS XML body and proper headers.
///
/// Headers set:
/// - `Content-Type: application/rss+xml; charset=utf-8`
/// - `X-Generator: PodcastFeedMaker` (configurable)
/// - `Cache-Control: public, max-age=N` (based on TTL config)
///
/// ```swift
/// let response = try FeedResponseEncoder.encode(feed, for: req)
/// ```
public struct FeedResponseEncoder: Sendable {

    /// Encodes a `PodcastFeed` into an HTTP `Response`.
    ///
    /// - Parameters:
    ///   - feed: The podcast feed to encode.
    ///   - request: The current Vapor request (used to access app configuration).
    /// - Returns: An HTTP response with XML body and proper headers.
    /// - Throws: `GeneratorError` if the feed cannot be serialized to XML.
    public static func encode(_ feed: PodcastFeed, for request: Request) throws -> Response {
        let config = request.application.feedConfiguration
        let generator = FeedGenerator(prettyPrint: config.prettyPrint)
        let xml = try generator.generate(feed)

        let response = Response(status: .ok)
        response.headers.contentType = config.contentType

        if let generatorName = config.generatorHeader {
            response.headers.add(name: "X-Generator", value: generatorName)
        }

        let maxAge = config.ttl.totalSeconds
        response.headers.add(name: .cacheControl, value: "public, max-age=\(maxAge)")

        response.body = .init(string: xml)
        return response
    }
}
