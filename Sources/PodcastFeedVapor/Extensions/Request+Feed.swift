import PodcastFeedMaker
import Vapor

extension Request {
    /// Encodes a `PodcastFeed` into an XML response using the app's feed configuration.
    ///
    /// ```swift
    /// app.get("feed.xml") { req in
    ///     try req.feedResponse(myFeed)
    /// }
    /// ```
    ///
    /// - Parameter feed: The podcast feed to encode.
    /// - Returns: An HTTP response with XML body and proper headers.
    /// - Throws: `GeneratorError` if the feed cannot be serialized.
    public func feedResponse(_ feed: PodcastFeed) throws -> Response {
        try FeedResponseEncoder.encode(feed, for: self)
    }
}
