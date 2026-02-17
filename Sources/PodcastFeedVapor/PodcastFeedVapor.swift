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
