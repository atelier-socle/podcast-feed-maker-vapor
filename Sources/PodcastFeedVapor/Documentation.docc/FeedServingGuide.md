# Feed Serving Guide

Three ways to serve podcast feeds: route builder DSL, response encoder, and streaming.

## Overview

PodcastFeedVapor provides multiple approaches to serve feeds, depending on your needs. The route builder DSL is the simplest; the response encoder gives more control; streaming handles very large feeds.

### Route Builder DSL

The `podcastFeed()` method on `RoutesBuilder` registers a GET route that encodes a `PodcastFeed` to XML automatically:

```swift
// Static feed
app.podcastFeed("feed.xml") { req in
    PodcastFeed(version: "2.0", namespaces: [], channel: myChannel)
}

// Nested path
app.podcastFeed("podcasts", "main", "feed.xml") { req in feed }

// Dynamic feed from route parameters
app.podcastFeed("shows", ":showId", "feed.xml") { req in
    let showId = req.parameters.get("showId") ?? "unknown"
    return try await loadFeed(for: showId, on: req.db)
}
```

Combine with middleware groups:

```swift
app.grouped(FeedCacheMiddleware(ttl: .hours(2)))
    .podcastFeed("feed.xml") { _ in feed }
```

### FeedResponseEncoder

For more control, use ``FeedResponseEncoder`` directly. It converts a `PodcastFeed` into a `Response` with XML body, `Content-Type`, `X-Generator`, and `Cache-Control` headers:

```swift
app.get("feed.xml") { req -> Response in
    let feed = try await buildFeed(on: req.db)
    return try FeedResponseEncoder.encode(feed, for: req)
}
```

A convenience method is available on `Request`:

```swift
app.get("feed.xml") { req -> Response in
    try req.feedResponse(myFeed)
}
```

For raw XML strings, use the `Response.xml()` factory:

```swift
app.get("raw.xml") { _ -> Response in
    Response.xml("<?xml version=\"1.0\"?><rss>...</rss>")
}
```

### Streaming

For feeds with thousands of episodes, ``StreamingFeedResponse`` avoids building the entire XML string in memory. XML chunks are streamed directly to the client using `StreamingFeedGenerator`:

```swift
app.get("large-feed.xml") { req -> Response in
    let feed = try await loadLargeFeed(on: req.db)
    return try await StreamingFeedResponse.stream(feed, for: req)
}
```

### Pagination

``FeedPagination`` extracts `?limit=N&offset=N` query parameters from the request with safe clamping:

```swift
app.podcastFeed("feed.xml") { req in
    let pagination = FeedPagination(from: req)
    // pagination.limit  → defaults to 50, max 1000
    // pagination.offset → defaults to 0
    let episodes = try await Episode.query(on: req.db)
        .sort(\.$pubDate, .descending)
        .offset(pagination.offset)
        .limit(pagination.limit)
        .all()
    return buildFeed(episodes: episodes)
}
```

| Parameter | Default | Max | Behavior |
|-----------|---------|-----|----------|
| `limit` | 50 | 1000 | Clamped to `[1, maxLimit]` |
| `offset` | 0 | — | Clamped to `>= 0` |

Custom limits:

```swift
let pagination = FeedPagination(from: req, defaultLimit: 25, maxLimit: 100)
```

## Next Steps

- <doc:FluentIntegration> — Map database models to feeds
- <doc:MiddlewareGuide> — Add caching, CORS, and generator headers
