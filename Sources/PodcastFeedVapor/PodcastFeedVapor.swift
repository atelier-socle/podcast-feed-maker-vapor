/// PodcastFeedVapor — Vapor middleware for serving podcast RSS feeds.
///
/// Built on PodcastFeedMaker, this library provides middleware, route builders,
/// caching, and Fluent integration for serving dynamic podcast feeds via Vapor.
///
/// ## Quick Start
///
/// ```swift
/// import Vapor
/// import PodcastFeedVapor
/// import PodcastFeedMaker
///
/// func configure(_ app: Application) throws {
///     app.middleware.use(PodcastFeedMiddleware())
///     app.healthCheck()
///
///     app.podcastFeed("feed.xml") { req in
///         PodcastFeed(version: "2.0", namespaces: [], channel: myChannel)
///     }
/// }
/// ```
///
/// ## Key Types
///
/// - ``PodcastFeedMiddleware``: Global middleware for feed headers
/// - ``FeedConfiguration``: Centralized settings (TTL, gzip, pretty-print)
/// - ``FeedResponseEncoder``: Converts `PodcastFeed` to HTTP Response
/// - ``FeedMappable``: Protocol for model to feed conversion
/// - ``StreamingCacheResponse``: Stream-through caching for large feeds
/// - ``FeedCacheStore``: Protocol for cache backends
/// - ``InMemoryFeedCache``: In-memory cache for development
/// - ``PodpingWebSocketManager``: Real-time feed update notifications via WebSocket
/// - ``PodpingMessage``: JSON messages for WebSocket Podping communication
import PodcastFeedMaker
import Vapor
