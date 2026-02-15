import PodcastFeedMaker
import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Middleware — X-Generator Header")
struct GeneratorMiddlewareShowcase {

    @Test("PodcastFeedMiddleware adds X-Generator to RSS responses")
    func addsGenerator() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.middleware.use(PodcastFeedMiddleware())
                app.podcastFeed("feed.xml") { _ in feed }
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers["X-Generator"].first == "PodcastFeedMaker")
                    }
                )
            }
        )
    }

    @Test("Custom generator header via configuration")
    func customGenerator() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.feedConfiguration.generatorHeader = "MyPodcastApp/2.0"
                app.middleware.use(PodcastFeedMiddleware())
                app.podcastFeed("feed.xml") { _ in feed }
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers["X-Generator"].first == "MyPodcastApp/2.0")
                    }
                )
            }
        )
    }

    @Test("Middleware skips non-RSS responses")
    func skipsNonRSS() async throws {
        try await withApp(
            configure: { app in
                app.middleware.use(PodcastFeedMiddleware())
                app.get(
                    "api", "data",
                    use: { _ -> [String: String] in
                        ["key": "value"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "api/data",
                    afterResponse: { res in
                        #expect(res.headers["X-Generator"].isEmpty)
                    }
                )
            }
        )
    }

    @Test("Disabled generator header — nil in config")
    func disabledGenerator() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.feedConfiguration.generatorHeader = nil
                app.podcastFeed("feed.xml") { _ in feed }
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers["X-Generator"].isEmpty)
                    }
                )
            }
        )
    }
}

@Suite("Middleware — HTTP Caching (ETag + Last-Modified + 304)")
struct CachingShowcase {

    @Test("Cache-Control header with configurable TTL")
    func cacheControl() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.grouped(FeedCacheMiddleware(ttl: .minutes(15))).get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.cacheControl].first == "public, max-age=900")
                    }
                )
            }
        )
    }

    @Test("ETag — same content produces same ETag")
    func sameETag() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.grouped(FeedCacheMiddleware()).get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                var firstETag = ""
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        firstETag = res.headers.first(name: .eTag) ?? ""
                    }
                )
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers.first(name: .eTag) == firstETag)
                    }
                )
            }
        )
    }

    @Test("ETag — different content produces different ETag")
    func differentETag() async throws {
        let feed1 = try makeTestFeed(title: "Show A")
        let feed2 = try makeTestFeed(title: "Show B")
        var etag1 = ""
        var etag2 = ""

        try await withApp(
            configure: { app in
                app.grouped(FeedCacheMiddleware()).get(
                    "feed1.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed1, for: req)
                    })
                app.grouped(FeedCacheMiddleware()).get(
                    "feed2.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed2, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed1.xml",
                    afterResponse: { res in
                        etag1 = res.headers.first(name: .eTag) ?? ""
                    }
                )
                try await app.testing().test(
                    .GET, "feed2.xml",
                    afterResponse: { res in
                        etag2 = res.headers.first(name: .eTag) ?? ""
                    }
                )
            }
        )

        #expect(etag1 != etag2)
    }

    @Test("304 Not Modified — conditional request with If-None-Match")
    func notModified() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.grouped(FeedCacheMiddleware()).get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                var etag = ""
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        etag = res.headers.first(name: .eTag) ?? ""
                        #expect(!etag.isEmpty)
                    }
                )
                try await app.testing().test(
                    .GET, "feed.xml",
                    beforeRequest: { req in
                        req.headers.replaceOrAdd(name: .ifNoneMatch, value: etag)
                    },
                    afterResponse: { res in
                        #expect(res.status == .notModified)
                        #expect(res.body.string.isEmpty)
                    }
                )
            }
        )
    }

    @Test("Last-Modified header in RFC 7231 format")
    func lastModified() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.grouped(FeedCacheMiddleware()).get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let lm = res.headers.first(name: .lastModified) ?? ""
                        #expect(lm.contains("GMT"))
                    }
                )
            }
        )
    }

    @Test("Full caching flow — first request 200, second request 304")
    func fullCachingFlow() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.grouped(FeedCacheMiddleware()).get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                var etag = ""
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(!res.body.string.isEmpty)
                        etag = res.headers.first(name: .eTag) ?? ""
                        #expect(res.headers[.cacheControl].first?.contains("max-age") == true)
                        let lm = res.headers.first(name: .lastModified) ?? ""
                        #expect(!lm.isEmpty)
                    }
                )
                try await app.testing().test(
                    .GET, "feed.xml",
                    beforeRequest: { req in
                        req.headers.replaceOrAdd(name: .ifNoneMatch, value: etag)
                    },
                    afterResponse: { res in
                        #expect(res.status == .notModified)
                        #expect(res.body.string.isEmpty)
                    }
                )
            }
        )
    }
}

@Suite("Middleware — CORS for Browser Clients")
struct CORSShowcase {

    @Test("Default CORS — wildcard origin for public feeds")
    func wildcardOrigin() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware()).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowOrigin].first == "*")
                    }
                )
            }
        )
    }

    @Test("Specific origins — restrict to known domains")
    func specificOrigins() async throws {
        let origins = ["https://myapp.com", "https://player.fm"]

        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware(allowedOrigins: origins)).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    beforeRequest: { req in
                        req.headers.replaceOrAdd(name: .origin, value: "https://myapp.com")
                    },
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowOrigin].first == "https://myapp.com")
                    }
                )
                try await app.testing().test(
                    .GET, "feed.xml",
                    beforeRequest: { req in
                        req.headers.replaceOrAdd(name: .origin, value: "https://evil.com")
                    },
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowOrigin].isEmpty)
                    }
                )
            }
        )
    }

    @Test("Preflight OPTIONS request — 204 No Content")
    func preflightOptions() async throws {
        try await withApp(
            configure: { app in
                app.middleware.use(CORSFeedMiddleware())
                app.get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .OPTIONS, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .noContent)
                        #expect(res.headers[.accessControlAllowOrigin].first == "*")
                    }
                )
            }
        )
    }

    @Test("Production setup — CORS + Cache + Generator middleware stacked")
    func stackedMiddleware() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.middleware.use(CORSFeedMiddleware())
                app.middleware.use(PodcastFeedMiddleware())
                app.grouped(FeedCacheMiddleware()).podcastFeed("feed.xml") { _ in feed }
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.headers[.accessControlAllowOrigin].first == "*")
                        #expect(res.headers[.cacheControl].first?.contains("max-age") == true)
                        #expect(res.headers.first(name: .eTag) != nil)
                        #expect(res.headers["X-Generator"].first != nil)
                        let contentType = res.headers.contentType?.serialize() ?? ""
                        #expect(contentType.contains("rss+xml"))
                    }
                )
            }
        )
    }
}
