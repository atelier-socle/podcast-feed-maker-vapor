# Middleware Guide

Three middlewares for production-quality podcast feed serving.

## Overview

PodcastFeedVapor provides three middlewares that work together to add proper HTTP headers, caching, and cross-origin support to your feed responses. Stack them in the right order for best results.

### PodcastFeedMiddleware

Adds the `X-Generator` header to all RSS/XML responses. The header value comes from ``FeedConfiguration/generatorHeader``.

```swift
app.middleware.use(PodcastFeedMiddleware())
```

Customize or disable the header via configuration:

```swift
app.feedConfiguration.generatorHeader = "MyPodcastApp/2.0"  // Custom value
app.feedConfiguration.generatorHeader = nil                  // Disable
```

The middleware only adds the header to responses with an RSS or XML content type — JSON and other responses pass through unchanged.

### FeedCacheMiddleware

Adds HTTP caching headers to RSS/XML responses:

| Header | Source |
|--------|--------|
| `ETag` | SHA256 hash of the response body |
| `Last-Modified` | Current timestamp in RFC 7231 format |
| `Cache-Control` | `public, max-age=N` from TTL configuration |

When a client sends `If-None-Match` with a matching ETag, the middleware returns `304 Not Modified` with an empty body — saving bandwidth.

```swift
// Use app-level TTL (from feedConfiguration)
app.grouped(FeedCacheMiddleware()).podcastFeed("feed.xml") { _ in feed }

// Override TTL per route group
app.grouped(FeedCacheMiddleware(ttl: .hours(2))).podcastFeed("feed.xml") { _ in feed }

// Selective features
app.middleware.use(FeedCacheMiddleware(
    ttl: .minutes(15),
    enableETag: true,
    enableLastModified: false
))
```

### CORSFeedMiddleware

Configures Cross-Origin Resource Sharing for feed endpoints. Essential when feeds are consumed by web-based podcast players.

```swift
// Allow all origins (development)
app.middleware.use(CORSFeedMiddleware())

// Restrict to specific origins (production)
app.middleware.use(CORSFeedMiddleware(
    allowedOrigins: ["https://myapp.com", "https://player.myapp.com"]
))
```

Handles `OPTIONS` preflight requests automatically with `204 No Content`. The `Access-Control-Max-Age` defaults to 86400 seconds (24 hours).

### Composition Order

Stack middlewares in this order for optimal behavior:

```swift
app.middleware.use(CORSFeedMiddleware())      // 1. CORS — outermost
app.middleware.use(PodcastFeedMiddleware())    // 2. Generator header
app.grouped(FeedCacheMiddleware())            // 3. Cache — innermost (per-route)
    .podcastFeed("feed.xml") { _ in feed }
```

All three middlewares produce headers on the same response:

| Header | Middleware |
|--------|-----------|
| `Access-Control-Allow-Origin` | ``CORSFeedMiddleware`` |
| `Access-Control-Allow-Methods` | ``CORSFeedMiddleware`` |
| `Access-Control-Max-Age` | ``CORSFeedMiddleware`` |
| `X-Generator` | ``PodcastFeedMiddleware`` |
| `ETag` | ``FeedCacheMiddleware`` |
| `Last-Modified` | ``FeedCacheMiddleware`` |
| `Cache-Control` | ``FeedCacheMiddleware`` |
| `Content-Type` | ``FeedResponseEncoder`` |

## Next Steps

- <doc:FeedServingGuide> — Route builder DSL, streaming, and pagination
- <doc:AdvancedFeatures> — Podping, batch audit, and health check
