#!/bin/bash
# Setup script for sample-vapor-server
# A functional test server for podcast-feed-maker-vapor
#
# Usage:
#   ./scripts/setup-sample-server.sh [target_directory]
#
# Default target: ../sample-vapor-server (sibling directory)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TARGET="${1:-$(dirname "$REPO_DIR")/sample-vapor-server}"

echo "Creating sample-vapor-server at $TARGET..."
mkdir -p "$TARGET/Sources/App"

# ─── Package.swift ───
cat > "$TARGET/Package.swift" << 'EOF'
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sample-vapor-server",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../podcast-feed-maker-vapor"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.121.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "PodcastFeedVapor", package: "podcast-feed-maker-vapor"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
    ]
)
EOF

# ─── Feeds.swift (isolated from Vapor to avoid NIO Channel conflict) ───
cat > "$TARGET/Sources/App/Feeds.swift" << 'EOF'
// Feeds.swift
// Sample Vapor Server — Feed factories
//
// Isolated from Vapor imports to avoid NIO `Channel` name collision.
// PodcastFeedMaker's `Channel` and `Item` resolve unambiguously here.

import Foundation
import PodcastFeedMaker

// MARK: - Static Feed

/// A simple static feed with 3 episodes for testing basic functionality.
func makeStaticFeed() -> PodcastFeed {
    PodcastFeed {
        Channel(
            title: "Test Podcast",
            link: URL(string: "https://example.com")!,
            description: "A test podcast for live validation"
        )
        .author("Test Host")
        .language("en-us")
        .explicit(false)
        .category(.technology)
        .image("https://example.com/artwork.jpg")

        Item(title: "Episode 1 — Pilot")
        Item(title: "Episode 2 — Deep Dive")
        Item(title: "Episode 3 — Finale")
    }
}

// MARK: - Dynamic Feed

/// A dynamic feed using route parameters and pagination.
func makeDynamicFeed(showId: String, limit: Int, offset: Int) -> PodcastFeed {
    var channel = Channel(
        title: "Show: \(showId)",
        link: URL(string: "https://example.com/shows/\(showId)")!,
        description: "Dynamic feed for \(showId) — showing \(limit) episodes from offset \(offset)"
    )
    .language("en-us")

    var items: [Item] = []
    for index in offset..<(offset + limit) {
        items.append(Item(title: "Episode \(index + 1) of \(showId)"))
    }
    channel.items = items

    return PodcastFeed {
        channel
    }
}

// MARK: - Rich Feed

/// A production-like feed with full metadata and enclosures.
func makeRichFeed() -> PodcastFeed {
    PodcastFeed {
        Channel(
            title: "The Swift Podcast",
            link: URL(string: "https://swiftpodcast.example.com")!,
            description: "Weekly conversations about Swift development"
        )
        .author("Jane Doe")
        .language("en-us")
        .copyright("© 2026 Swift Podcast")
        .category(.technology)
        .explicit(false)
        .image("https://cdn.example.com/artwork.jpg")
        .type("episodic")
        .owner(name: "Jane Doe", email: "jane@swiftpodcast.example.com")
        .locked(owner: "jane@swiftpodcast.example.com")
        .guid("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        .funding(url: "https://patreon.com/swiftpodcast", text: "Support on Patreon")
        .atomLink(href: "https://swiftpodcast.example.com/feed.xml", rel: "self")
        .medium(.podcast)

        Item(
            title: "S1E1: Getting Started with Swift 6",
            enclosure: Enclosure.mp3(
                url: "https://cdn.example.com/s1e1.mp3",
                length: 45_000_000
            )
        )
        .description("Everything you need to know about Swift 6 concurrency.")
        .guid("s1e1-swift6", isPermaLink: false)
        .pubDate(Date(timeIntervalSince1970: 1_700_000_000))
        .duration(2700)
        .explicit(false)
        .season(1)
        .episode(1)
        .episodeType("full")

        Item(
            title: "S1E2: Structured Concurrency Deep Dive",
            enclosure: Enclosure.mp3(
                url: "https://cdn.example.com/s1e2.mp3",
                length: 52_000_000
            )
        )
        .description("Actors, tasks, and async sequences explained.")
        .guid("s1e2-concurrency", isPermaLink: false)
        .pubDate(Date(timeIntervalSince1970: 1_700_600_000))
        .duration(3120)
        .explicit(false)
        .season(1)
        .episode(2)
        .episodeType("full")
    }
}
EOF

# ─── App.swift (Vapor entry point) ───
cat > "$TARGET/Sources/App/App.swift" << 'EOF'
// App.swift
// Sample Vapor Server
//
// A functional test server demonstrating all podcast-feed-maker-vapor features.
// Used for manual validation (curl tests) during development.
//
// Usage:
//   swift run
//   curl http://localhost:8080/health
//   curl http://localhost:8080/feed.xml
//   curl http://localhost:8080/rich/feed.xml
//   curl http://localhost:8080/shows/my-show/feed.xml?limit=5&offset=10
//   curl http://localhost:8080/feeds/audit?urls=https://feeds.simplecast.com/54nAGcIl

import Vapor
import PodcastFeedVapor

@main
struct App {
    static func main() async throws {
        let app = try await Application.make()

        // ─── Configuration ───
        app.feedConfiguration = FeedConfiguration(
            ttl: CacheControlDuration.minutes(5),
            prettyPrint: true,
            generatorHeader: "SampleVaporServer/1.0"
        )

        // ─── Middleware Stack ───
        // Order matters: CORS first, then cache, then generator header
        app.middleware.use(CORSFeedMiddleware())
        app.middleware.use(FeedCacheMiddleware(ttl: CacheControlDuration.minutes(5)))
        app.middleware.use(PodcastFeedMiddleware())

        // ─── Endpoints ───

        // Health check: GET /health
        app.healthCheck()

        // Batch audit: GET /feeds/audit?urls=...
        app.batchAudit("feeds", "audit")

        // Static feed: GET /feed.xml
        app.podcastFeed("feed.xml") { _ in
            makeStaticFeed()
        }

        // Rich feed with full metadata: GET /rich/feed.xml
        app.podcastFeed("rich", "feed.xml") { _ in
            makeRichFeed()
        }

        // Dynamic feed with route params + pagination: GET /shows/:showId/feed.xml
        app.podcastFeed("shows", ":showId", "feed.xml") { req in
            let showId = req.parameters.get("showId") ?? "unknown"
            let pagination = FeedPagination(from: req)
            return makeDynamicFeed(
                showId: showId,
                limit: pagination.limit,
                offset: pagination.offset
            )
        }

        // Non-RSS JSON route (to verify middleware skips non-feed responses)
        app.get("api", "status") { _ in
            ["status": "ok", "server": "sample-vapor-server"]
        }

        try await app.execute()
        try await app.asyncShutdown()
    }
}
EOF

# ─── .gitignore ───
cat > "$TARGET/.gitignore" << 'EOF'
.DS_Store
.build/
.swiftpm/
Package.resolved
*.xcodeproj
DerivedData/
EOF

# ─── README.md ───
cat > "$TARGET/README.md" << 'EOF'
# Sample Vapor Server

A functional test server for [podcast-feed-maker-vapor](https://github.com/atelier-socle/podcast-feed-maker-vapor), demonstrating all library features with real HTTP endpoints.

## Quick Start
```bash
swift run
```

The server starts on `http://localhost:8080`.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check (JSON) |
| GET | `/feed.xml` | Static feed — 3 episodes |
| GET | `/rich/feed.xml` | Rich feed — full metadata, enclosures, Podcast NS 2.0 |
| GET | `/shows/:showId/feed.xml` | Dynamic feed with route parameters |
| GET | `/shows/:showId/feed.xml?limit=N&offset=N` | Dynamic feed with pagination |
| GET | `/feeds/audit?urls=URL1,URL2` | Batch audit — parallel feed quality scoring |
| OPTIONS | `/feed.xml` | CORS preflight |
| GET | `/api/status` | Non-RSS JSON endpoint (middleware skip test) |

## Test Scenarios
```bash
# Health check
curl -s http://localhost:8080/health | python3 -m json.tool

# Feed XML with all headers
curl -sI http://localhost:8080/feed.xml

# ETag + 304 Not Modified
ETAG=$(curl -sI http://localhost:8080/feed.xml | grep -i etag | awk '{print $2}' | tr -d '\r')
curl -s -o /dev/null -w "%{http_code}" -H "If-None-Match: $ETAG" http://localhost:8080/feed.xml

# CORS preflight
curl -s -X OPTIONS -H "Origin: https://myapp.com" -o /dev/null -w "%{http_code}" http://localhost:8080/feed.xml

# Dynamic feed with pagination
curl -s "http://localhost:8080/shows/tech/feed.xml?limit=5&offset=10"

# Rich feed with full metadata
curl -s http://localhost:8080/rich/feed.xml | xmllint --format -

# Batch audit
curl -s "http://localhost:8080/feeds/audit?urls=https://feeds.simplecast.com/54nAGcIl" | python3 -m json.tool

# Verify non-RSS middleware skip
curl -sI http://localhost:8080/api/status | grep -E "x-generator|cache-control|etag"
# (should return nothing — middlewares skip non-RSS responses)
```

## Features Demonstrated

- **FeedConfiguration** — TTL, pretty-print, custom generator header
- **PodcastFeedMiddleware** — X-Generator header on RSS responses only
- **FeedCacheMiddleware** — ETag (SHA256), Last-Modified, Cache-Control, 304 Not Modified
- **CORSFeedMiddleware** — Wildcard origin, preflight OPTIONS, max-age
- **FeedRouteBuilder** — `app.podcastFeed()` DSL with static and dynamic routes
- **FeedPagination** — Query parameter parsing with clamping
- **BatchAuditEndpoint** — Parallel feed quality scoring with grades
- **HealthCheck** — JSON status with version and uptime

## Architecture Note

`Feeds.swift` is intentionally separated from `App.swift` to avoid the NIO `Channel` type collision with PodcastFeedMaker's `Channel`. Files that import both `Vapor` and `PodcastFeedMaker` would encounter ambiguity; keeping feed construction in a Vapor-free file resolves this cleanly.

## Requirements

- Swift 6.2+
- macOS 14+
- podcast-feed-maker-vapor (sibling directory)
EOF

echo ""
echo "✅ sample-vapor-server created at $TARGET"
echo ""
echo "To run:"
echo "  cd $TARGET"
echo "  swift run"
echo ""
echo "Then test with:"
echo "  curl http://localhost:8080/health"
echo "  curl http://localhost:8080/feed.xml"
