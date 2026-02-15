# Redis and Queues

Optional targets for production deployments: Redis-backed feed caching and background feed regeneration.

## Overview

PodcastFeedVapor ships two optional targets that add no dependencies to your core application unless you import them. Use `PodcastFeedVaporRedis` for feed caching and `PodcastFeedVaporQueues` for background regeneration.

### PodcastFeedVaporRedis

Add to your `Package.swift`:

```swift
.product(name: "PodcastFeedVaporRedis", package: "podcast-feed-maker-vapor")
```

#### FeedCacheStore Protocol

The `FeedCacheStore` protocol defines four methods for any cache backend:

```swift
let cache: any FeedCacheStore = myCache

// Store generated XML with a TTL
try await cache.set(identifier: "show-123", xml: feedXML, ttl: 300)

// Retrieve cached XML
if let cached = try await cache.get(identifier: "show-123") {
    return cached  // Cache hit — skip regeneration
}

// Invalidate a specific feed
try await cache.invalidate(identifier: "show-123")

// Clear all cached feeds
try await cache.invalidateAll()
```

#### RedisFeedCache

`RedisFeedCache` implements `FeedCacheStore` with Redis as the backend. It uses `SETEX` for TTL-based storage and `SCAN` (not `KEYS`) for production-safe bulk invalidation.

```swift
import PodcastFeedVaporRedis

// Default: prefix "feed:", TTL 300s (5 min)
let cache = RedisFeedCache(application: app)

// Custom configuration
let cache = RedisFeedCache(application: app, keyPrefix: "myapp:feed:", defaultTTL: 600)

// Convenience factory
let cache = app.redisFeedCache(keyPrefix: "myapp:feed:", defaultTTL: 600)
```

### PodcastFeedVaporQueues

Add to your `Package.swift`:

```swift
.product(name: "PodcastFeedVaporQueues", package: "podcast-feed-maker-vapor")
```

#### FeedRegenerationHandler Protocol

Implement `FeedRegenerationHandler` to provide your regeneration logic:

```swift
struct MyFeedRegenerator: FeedRegenerationHandler {
    func regenerate(feedIdentifier: String, reason: String?, context: QueueContext) async throws {
        let show = try await Show.find(feedIdentifier, on: context.application.db)
        let xml = try FeedGenerator().generate(show.toPodcastFeed())
        try await cache.set(identifier: feedIdentifier, xml: xml, ttl: 600)
    }
}
```

#### FeedRegenerationJob

`FeedRegenerationJob` is an `AsyncJob` that delegates to your handler. Register it during app setup:

```swift
import PodcastFeedVaporQueues
import QueuesRedisDriver

// In configure.swift
try app.queues.use(.redis(url: "redis://127.0.0.1:6379"))
app.registerFeedRegenerationJob(handler: MyFeedRegenerator())
```

Dispatch a job when content changes:

```swift
try await req.queue.dispatch(
    FeedRegenerationJob.self,
    FeedRegenerationPayload(feedIdentifier: "show-123", reason: "episode_added")
)
```

`FeedRegenerationPayload` carries the feed identifier and an optional freeform reason string:

```swift
let payload = FeedRegenerationPayload(feedIdentifier: "show-123", reason: "episode_added")
let payload = FeedRegenerationPayload(feedIdentifier: "show-456")  // reason is nil
```

The job logs progress and errors via the queue context's logger. The error handler logs failures without rethrowing, allowing the queue's retry policy to control behavior.
