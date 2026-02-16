# ``PodcastFeedVapor``

@Metadata {
    @DisplayName("PodcastFeedVapor")
}

Vapor middleware for serving podcast RSS feeds.

## Overview

**PodcastFeedVapor** is a Vapor middleware library for serving dynamic podcast RSS feeds. Built on [PodcastFeedMaker](https://github.com/atelier-socle/podcast-feed-maker), it provides HTTP caching (ETag, Last-Modified, 304), CORS, chunked streaming, pagination, Podping notifications, batch feed auditing, and Fluent model mapping. Optional Redis cache and queue worker targets let you scale without adding dependencies to your core.

```swift
import PodcastFeedVapor

func configure(_ app: Application) throws {
    app.feedConfiguration = FeedConfiguration(
        ttl: .hours(1),
        prettyPrint: false,
        generatorHeader: "MyApp/1.0"
    )
    app.healthCheck()
    app.middleware.use(CORSFeedMiddleware())
    app.middleware.use(PodcastFeedMiddleware())
    app.grouped(FeedCacheMiddleware()).podcastFeed("feed.xml") { req in
        // Return a PodcastFeed built from your database
        try await loadFeed(on: req.db)
    }
}
```

### Key Features

- **Middleware** — X-Generator header, ETag/304 caching, CORS with preflight
- **Route Builder** — `app.podcastFeed("feed.xml")` DSL for feed routes
- **Streaming** — Chunked XML streaming for large feeds via `StreamingFeedGenerator`
- **Pagination** — Query parameter parsing (`?limit=N&offset=N`) with safe clamping
- **Podping** — Feed update notifications via webhook
- **Batch Audit** — Parallel feed quality scoring via `FeedAuditor`
- **Fluent Mapping** — Protocol-based model-to-feed conversion
- **Redis Cache** — Optional `FeedCacheStore` protocol + Redis implementation
- **Queue Workers** — Optional background feed regeneration jobs

### How It Works

1. **Configure** — Set up ``FeedConfiguration`` with TTL, generator header, and pretty-print options
2. **Middleware** — Stack ``CORSFeedMiddleware``, ``FeedCacheMiddleware``, and ``PodcastFeedMiddleware``
3. **Routes** — Register feed routes with `app.podcastFeed()` DSL
4. **Serve** — Handler returns a `PodcastFeed` which is automatically encoded to XML with proper headers

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:MiddlewareGuide>
- <doc:FeedServingGuide>
- <doc:StreamingCacheGuide>

### Integration

- <doc:FluentIntegration>
- <doc:AdvancedFeatures>
- <doc:RedisAndQueues>

### Configuration

- ``FeedConfiguration``
- ``CacheControlDuration``

### Middleware

- ``PodcastFeedMiddleware``
- ``FeedCacheMiddleware``
- ``CORSFeedMiddleware``

### Feed Encoding

- ``FeedResponseEncoder``
- ``StreamingFeedResponse``
- ``FeedPagination``

### Fluent Mapping

- ``FeedMappable``
- ``ChannelMappable``
- ``ItemMappable``

### Podping

- ``PodpingNotifier``
- ``PodpingReason``
- ``PodpingMedium``
- ``PodpingError``

### Batch Audit

- ``BatchAuditResult``

### Caching

- ``FeedCacheStore``
- ``InMemoryFeedCache``
- ``StreamingCacheResponse``
- ``XMLCollector``

### Health

- ``HealthResponse``
