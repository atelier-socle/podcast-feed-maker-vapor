/// PodcastFeedVapor — Vapor middleware for serving podcast RSS feeds.
///
/// Built on PodcastFeedMaker, this library provides middleware, route builders,
/// caching, and Fluent integration for serving dynamic podcast feeds via Vapor.
///
/// ## Quick Start
///
/// ```swift
/// import PodcastFeedVapor
///
/// func configure(_ app: Application) throws {
///     app.healthCheck()
/// }
/// ```
import PodcastFeedMaker
import Vapor
