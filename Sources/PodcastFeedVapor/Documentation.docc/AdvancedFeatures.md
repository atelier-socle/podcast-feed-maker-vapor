# Advanced Features

Podping notifications, batch feed auditing, and health checks.

## Overview

PodcastFeedVapor includes three production features beyond core feed serving: Podping notifications for real-time feed updates, batch auditing for feed quality scoring, and a health check endpoint for monitoring.

### Podping Notifications

``PodpingNotifier`` sends webhook notifications when a podcast feed is updated. Podping is the podcast industry's notification system — instead of aggregators polling thousands of feeds, hosting platforms send a single notification when content changes.

```swift
let notifier = PodpingNotifier(
    client: req.client,
    endpoint: "https://podping.cloud",
    authToken: "your-auth-token"
)
try await notifier.notify(
    feedURL: "https://example.com/feed.xml",
    reason: .update,
    medium: .podcast
)
```

Available reasons (``PodpingReason``):

| Reason | Description |
|--------|-------------|
| `.update` | Feed was updated (new episode, changed metadata) |
| `.live` | A livestream has started |
| `.liveEnd` | A livestream has ended |

Available media types (``PodpingMedium``): `podcast`, `music`, `video`, `film`, `audiobook`, `newsletter`, `blog`.

Errors are reported as ``PodpingError`` — either `.serverError(statusCode)` or `.invalidEndpoint(url)`.

### WebSocket Podping

For real-time notifications, register a WebSocket endpoint with
``PodpingWebSocketManager``. Clients connect and receive JSON messages
when feeds are updated — no polling required.

```swift
// Register WebSocket endpoint
app.podpingWebSocket("podping")

// When a feed is updated, broadcast to all connected clients
await app.podpingWebSocketManager.broadcast(
    feedURL: "https://example.com/feed.xml",
    reason: .update,
    medium: .podcast
)
```

Clients can subscribe to specific feeds by sending a JSON message:

```json
{
    "kind": "subscribe",
    "feedURLs": ["https://example.com/feed.xml"]
}
```

Messages use ``PodpingMessage`` with these kinds:

| Kind | Direction | Description |
|------|-----------|-------------|
| `welcome` | Server → Client | Sent on connection |
| `notification` | Server → Client | Feed update notification |
| `subscribed` | Server → Client | Subscription confirmation |
| `subscribe` | Client → Server | Subscribe to feeds |
| `unsubscribe` | Client → Server | Unsubscribe from feeds |

Clients with no subscriptions receive all notifications (broadcast mode).

### Batch Feed Auditing

Register a batch audit endpoint that scores multiple feeds in parallel using PodcastFeedMaker's `FeedAuditor`:

```swift
app.batchAudit("feeds", "audit")
```

Query with comma-separated URLs (maximum 20 per request):

```bash
GET /feeds/audit?urls=https://a.com/feed.xml,https://b.com/feed.xml
```

Returns a JSON array of ``BatchAuditResult`` objects:

```json
[
    {"url": "https://a.com/feed.xml", "score": 85, "grade": "B+", "recommendationCount": 3},
    {"url": "https://b.com/feed.xml", "score": 0, "grade": "F", "error": "Connection refused"}
]
```

Create results programmatically:

```swift
let success = BatchAuditResult(url: "https://example.com/feed.xml", score: 85, grade: "B+", recommendationCount: 3)
let failure = BatchAuditResult.failure(url: "https://bad.com/feed.xml", error: "Connection refused")
```

### Health Check

Register a health check endpoint for monitoring and load balancers:

```swift
app.healthCheck()           // GET /health (default path)
app.healthCheck(path: "hz") // GET /hz (custom path)
```

Returns a ``HealthResponse`` with service status, library version, and server uptime:

```json
{"status": "ok", "version": "0.3.0", "uptime": 3600}
```

## Next Steps

- <doc:RedisAndQueues> — Optional Redis cache and queue workers
- <doc:MiddlewareGuide> — Caching, CORS, and generator header
