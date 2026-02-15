import PodcastFeedMaker
import Vapor

/// Creates a streaming HTTP response from a ``PodcastFeed`` using
/// PodcastFeedMaker's ``StreamingFeedGenerator``.
///
/// For feeds with thousands of episodes, this avoids building the entire XML
/// string in memory. Instead, XML chunks are streamed directly to the client.
///
/// ```swift
/// app.get("large-feed.xml") { req -> Response in
///     let feed = try await loadLargeFeed(on: req.db)
///     return try await StreamingFeedResponse.stream(feed, for: req)
/// }
/// ```
public struct StreamingFeedResponse: Sendable {

    /// Creates a streaming HTTP response for a podcast feed.
    ///
    /// Uses ``StreamingFeedGenerator`` to produce XML chunks that are
    /// written to the response body as they are generated.
    ///
    /// - Parameters:
    ///   - feed: The podcast feed to stream.
    ///   - request: The Vapor request (for configuration access).
    /// - Returns: A streaming HTTP response with chunked XML.
    public static func stream(_ feed: PodcastFeed, for request: Request) async throws -> Response {
        let config = request.application.feedConfiguration
        let generator = StreamingFeedGenerator(prettyPrint: config.prettyPrint)

        let response = Response(status: .ok)
        response.headers.contentType = config.contentType
        if let generatorName = config.generatorHeader {
            response.headers.add(name: "X-Generator", value: generatorName)
        }

        let maxAge = config.ttl.totalSeconds
        response.headers.add(name: .cacheControl, value: "public, max-age=\(maxAge)")

        response.body = .init(managedAsyncStream: { writer in
            for try await chunk in generator.generate(feed) {
                try await writer.writeBuffer(ByteBuffer(string: chunk))
            }
        })

        return response
    }
}
