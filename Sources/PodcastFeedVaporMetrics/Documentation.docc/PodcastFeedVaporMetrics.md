# ``PodcastFeedVaporMetrics``

@Metadata {
    @DisplayName("PodcastFeedVaporMetrics")
}

Feed serving metrics via the swift-metrics API.

## Overview

**PodcastFeedVaporMetrics** provides a Vapor middleware that emits feed serving
metrics using Apple's [swift-metrics](https://github.com/apple/swift-metrics) API.
Compatible with any backend — Prometheus, StatsD, Datadog, and more.

### Quick Start

```swift
import PodcastFeedVapor
import PodcastFeedVaporMetrics

func configure(_ app: Application) throws {
    // Add metrics middleware (before other feed middleware)
    app.middleware.use(FeedMetricsMiddleware())
    app.middleware.use(PodcastFeedMiddleware())

    app.podcastFeed("feed.xml") { req in
        try await loadFeed(on: req.db)
    }
}
```

### Metrics Emitted

All metrics are prefixed with `pfv_` by default (configurable):

- **`pfv_feed_requests_total`** — Counter. Dimensions: route, status, cache (hit/miss/none)
- **`pfv_feed_request_duration_seconds`** — Timer. Dimensions: route, status
- **`pfv_feed_response_size_bytes`** — Recorder. Dimensions: route
- **`pfv_feed_active_streams`** — Gauge. Active streaming connections (via `FeedActiveStreamsGauge` actor, use `await`)

### Backend Setup

swift-metrics is backend-agnostic. Add your preferred backend:

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

## Topics

### Middleware

- ``FeedMetricsMiddleware``

### Configuration

- ``FeedMetricsConfiguration``

### Gauges

- ``FeedActiveStreamsGauge``
