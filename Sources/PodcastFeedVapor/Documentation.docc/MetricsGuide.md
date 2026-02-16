# Metrics

Optional feed serving metrics via the swift-metrics API.

## Overview

The `PodcastFeedVaporMetrics` target provides a Vapor middleware that emits feed serving metrics using Apple's [swift-metrics](https://github.com/apple/swift-metrics) API. It is backend-agnostic — use Prometheus, StatsD, Datadog, or any compatible backend.

Add it to your `Package.swift`:

```swift
.product(name: "PodcastFeedVaporMetrics", package: "podcast-feed-maker-vapor")
```

### Middleware Setup

Register `FeedMetricsMiddleware` **before** other feed middleware so it wraps the full request lifecycle:

```swift
import PodcastFeedVapor
import PodcastFeedVaporMetrics

func configure(_ app: Application) throws {
    app.middleware.use(FeedMetricsMiddleware())
    app.middleware.use(CORSFeedMiddleware())
    app.middleware.use(PodcastFeedMiddleware())

    app.grouped(FeedCacheMiddleware()).podcastFeed("feed.xml") { req in
        try await loadFeed(on: req.db)
    }
}
```

### Metrics Emitted

All metric names are prefixed with `pfv_` by default:

| Metric | Type | Dimensions |
|--------|------|------------|
| `pfv_feed_requests_total` | Counter | route, status, cache (hit/miss/none) |
| `pfv_feed_request_duration_seconds` | Timer | route, status |
| `pfv_feed_response_size_bytes` | Recorder | route |
| `pfv_feed_active_streams` | Gauge | — |

Cache status is inferred from the response: 304 or ETag present → `hit`, RSS without ETag → `miss`, non-feed → `none`.

### Custom Prefix

Use a custom prefix to namespace metrics for your application:

```swift
app.middleware.use(FeedMetricsMiddleware(prefix: "myapp"))
// Emits: myapp_feed_requests_total, myapp_feed_request_duration_seconds, etc.
```

### Active Streams Gauge

`FeedActiveStreamsGauge` is an actor that tracks the number of active streaming feed responses. Call `increment()` when a stream starts and `decrement()` when it ends:

```swift
let streams = FeedActiveStreamsGauge()
await streams.increment()   // Stream started
// ... streaming ...
await streams.decrement()   // Stream ended
```

The count is clamped to zero — decrementing below zero is safe.

### Configuration

Store metrics configuration in Vapor's application storage:

```swift
app.feedMetricsConfiguration = FeedMetricsConfiguration(
    prefix: "myapp",
    enableResponseSizeRecording: false
)
```

### Backend Setup

swift-metrics is backend-agnostic. Add your preferred backend package and bootstrap before starting the server:

```swift
// Prometheus example
import SwiftPrometheus
let prometheus = PrometheusClient()
MetricsSystem.bootstrap(PrometheusMetricsFactory(client: prometheus))

// StatsD example
import StatsdClient
let statsd = try StatsdClient(host: "localhost", port: 8125)
MetricsSystem.bootstrap(statsd)
```

## Next Steps

- <doc:MiddlewareGuide> — Caching, CORS, and generator header
- <doc:StreamingCacheGuide> — Streaming cache for large feeds
- <doc:RedisAndQueues> — Optional Redis cache and queue workers
