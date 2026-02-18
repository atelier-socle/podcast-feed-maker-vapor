# Getting Started

Install PodcastFeedVapor and serve your first podcast feed in minutes.

## Overview

PodcastFeedVapor turns any Vapor application into a podcast RSS feed server. Add the package, register a route, and return a `PodcastFeed` — the library handles XML encoding, content-type headers, caching, and CORS automatically.

### Add the Dependency

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/atelier-socle/podcast-feed-maker-vapor.git", from: "0.3.0")
]
```

Three products are available — import only what you need:

| Product | Description |
|---------|-------------|
| `PodcastFeedVapor` | Core library (required) — middleware, routes, encoding |
| `PodcastFeedVaporRedis` | Optional — Redis-backed feed cache |
| `PodcastFeedVaporQueues` | Optional — Background feed regeneration jobs |

Add the core product to your target:

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "PodcastFeedVapor", package: "podcast-feed-maker-vapor")
    ]
)
```

### Import the Module

```swift
import PodcastFeedVapor
```

### Minimal Setup

Register a feed route and a health check endpoint:

```swift
func configure(_ app: Application) throws {
    app.healthCheck()
    app.podcastFeed("feed.xml") { req in
        // Build and return a PodcastFeed
        PodcastFeed(version: "2.0", namespaces: [], channel: myChannel)
    }
}
```

### Custom Configuration

Control TTL, pretty-printing, and the generator header:

```swift
app.feedConfiguration = FeedConfiguration(
    ttl: .hours(1),
    prettyPrint: true,
    generatorHeader: "MyApp/1.0"
)
```

### Test It

```bash
# Health check
curl http://localhost:8080/health
# → {"status":"ok","version":"0.3.0","uptime":42}

# Feed
curl http://localhost:8080/feed.xml
# → <?xml version="1.0" encoding="UTF-8"?><rss ...>
```

## Next Steps

- <doc:MiddlewareGuide> — Add caching, CORS, and generator headers
- <doc:FeedServingGuide> — Route builder DSL, streaming, and pagination
