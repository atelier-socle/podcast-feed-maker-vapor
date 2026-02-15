import PodcastFeedMaker
import Vapor

extension RoutesBuilder {
    /// Registers a GET route that serves a podcast RSS feed.
    ///
    /// The handler closure receives the Vapor `Request` and must return a `PodcastFeed`.
    /// The feed is automatically encoded to XML with proper headers.
    ///
    /// ```swift
    /// // Static feed
    /// app.podcastFeed("feed.xml") { req in
    ///     PodcastFeed(version: "2.0", namespaces: [], channel: myChannel)
    /// }
    ///
    /// // Dynamic feed with route parameters
    /// app.podcastFeed("shows", ":showId", "feed.xml") { req in
    ///     let showId = try req.parameters.require("showId", as: UUID.self)
    ///     return try await loadFeed(for: showId, on: req.db)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: One or more path components for the route.
    ///   - handler: An async closure that produces a `PodcastFeed`.
    /// - Returns: The registered `Route`.
    @discardableResult
    public func podcastFeed(
        _ path: PathComponent...,
        handler: @Sendable @escaping (Request) async throws -> PodcastFeed
    ) -> Route {
        self.on(
            .GET, path,
            use: { request async throws -> Response in
                let feed = try await handler(request)
                return try FeedResponseEncoder.encode(feed, for: request)
            })
    }
}
