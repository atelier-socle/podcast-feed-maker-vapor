# Streaming Cache

Combine chunked XML streaming with cache-through caching for maximum performance.

## Overview

For very large feeds (10,000+ episodes), XML generation is CPU-intensive.
``StreamingCacheResponse`` solves this by streaming the feed to the client
while simultaneously caching the complete XML. Subsequent requests serve
directly from the cache.

### How It Works

1. Client requests a feed
2. The cache store is checked for a cached version
3. **Cache hit** — serve directly from cache with ETag (supports 304 Not Modified)
4. **Cache miss** — stream XML to client, buffer chunks, store full XML in cache when done

### Basic Usage

```swift
import PodcastFeedVapor

let cache = InMemoryFeedCache()

app.get("large-feed.xml") { req -> Response in
    let feed = try await loadLargeFeed(on: req.db)
    return try await StreamingCacheResponse.stream(
        feed,
        for: req,
        cache: cache,
        identifier: "show-123"
    )
}
```

### With Redis

```swift
import PodcastFeedVaporRedis

let cache = app.redisFeedCache(keyPrefix: "feed:", defaultTTL: 600)

app.get("shows", ":showId", "feed.xml") { req -> Response in
    let showId = try req.parameters.require("showId")
    let feed = try await loadFeed(for: showId, on: req.db)
    return try await StreamingCacheResponse.stream(
        feed,
        for: req,
        cache: cache,
        identifier: showId,
        ttl: .hours(1)
    )
}
```

### Custom TTL

The TTL defaults to the application's ``FeedConfiguration/ttl``.
Override per-route:

```swift
return try await StreamingCacheResponse.stream(
    feed,
    for: req,
    cache: cache,
    identifier: "show-123",
    ttl: .minutes(15)
)
```

### Cache Invalidation

Invalidate when feed content changes:

```swift
// Single feed
try await cache.invalidate(identifier: "show-123")

// All feeds
try await cache.invalidateAll()
```

### ETag Support

Cached responses include an ETag header (SHA256 of the XML body).
Clients can send `If-None-Match` to receive a 304 Not Modified response,
avoiding bandwidth for unchanged feeds.

## Topics

### Types

- ``StreamingCacheResponse``
- ``FeedCacheStore``
- ``InMemoryFeedCache``
- ``XMLCollector``
