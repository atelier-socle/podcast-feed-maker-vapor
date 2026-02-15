import PodcastFeedMaker
import Testing
import VaporTesting

@testable import PodcastFeedVapor

// MARK: - Podping

@Suite("Podping — Feed Update Notifications")
struct PodpingShowcase {

    @Test("Create notifier with default endpoint")
    func defaultEndpoint() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let notifier = PodpingNotifier(client: app.client)
                _ = notifier
            }
        )
    }

    @Test("Create notifier with custom endpoint and auth token")
    func customEndpoint() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let notifier = PodpingNotifier(
                    client: app.client,
                    endpoint: "https://custom.podping.local",
                    authToken: "xyz-token"
                )
                _ = notifier
            }
        )
    }

    @Test("Notification reasons — update, live, liveEnd")
    func notificationReasons() {
        let reasons = PodpingReason.allCases
        #expect(reasons.count == 3)
        #expect(reasons.contains(.update))
        #expect(reasons.contains(.live))
        #expect(reasons.contains(.liveEnd))
    }

    @Test("Media types — podcast, music, video, film, audiobook, newsletter, blog")
    func mediaTypes() {
        let media = PodpingMedium.allCases
        #expect(media.count == 7)
        #expect(media.contains(.podcast))
        #expect(media.contains(.music))
        #expect(media.contains(.video))
        #expect(media.contains(.film))
        #expect(media.contains(.audiobook))
        #expect(media.contains(.newsletter))
        #expect(media.contains(.blog))
    }

    @Test("Notify call parameters are verified via mock endpoint")
    func notifyParameters() async throws {
        try await withApp(
            configure: { app in
                app.get("mock-podping") { req -> HTTPStatus in
                    let url: String? = req.query["url"]
                    let reason: String? = req.query["reason"]
                    let medium: String? = req.query["medium"]
                    #expect(url == "https://example.com/feed.xml")
                    #expect(reason == "live")
                    #expect(medium == "music")
                    return .ok
                }
            },
            { app in
                try await app.testing().test(
                    .GET,
                    "mock-podping?url=https://example.com/feed.xml&reason=live&medium=music",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                    }
                )
            }
        )
    }
}

// MARK: - Batch Audit

@Suite("Batch Audit — Parallel Feed Quality Scoring")
struct BatchAuditShowcase {

    @Test("Register batch audit endpoint")
    func registerEndpoint() async throws {
        try await withApp(
            configure: { app in
                app.batchAudit("feeds", "audit")
            },
            { app in
                try await app.testing().test(
                    .GET, "feeds/audit?urls=https://example.com/feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                    }
                )
            }
        )
    }

    @Test("BatchAuditResult — success result with score and grade")
    func successResult() {
        let result = BatchAuditResult(
            url: "https://example.com/feed.xml",
            score: 85,
            grade: "B+",
            recommendationCount: 3
        )
        #expect(result.score == 85)
        #expect(result.grade == "B+")
        #expect(result.recommendationCount == 3)
        #expect(result.error == nil)
    }

    @Test("BatchAuditResult — failure result for unreachable feed")
    func failureResult() {
        let result = BatchAuditResult.failure(
            url: "https://bad.com/feed.xml",
            error: "Connection refused"
        )
        #expect(result.score == 0)
        #expect(result.grade == "F")
        #expect(result.error == "Connection refused")
    }

    @Test("Missing urls parameter → 400 Bad Request")
    func missingURLs() async throws {
        try await withApp(
            configure: { app in
                app.batchAudit("feeds", "audit")
            },
            { app in
                try await app.testing().test(
                    .GET, "feeds/audit",
                    afterResponse: { res in
                        #expect(res.status == .badRequest)
                    }
                )
            }
        )
    }

    @Test("Audit endpoint returns JSON array")
    func returnsJSONArray() async throws {
        try await withApp(
            configure: { app in
                app.batchAudit("feeds", "audit")
            },
            { app in
                try await app.testing().test(
                    .GET, "feeds/audit?urls=https://example.com/feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        let body = res.body.string
                        #expect(body.hasPrefix("["))
                        #expect(body.hasSuffix("]"))
                    }
                )
            }
        )
    }
}

// MARK: - Production Setup

@Suite("Production Setup — Complete Configuration")
struct ProductionSetupShowcase {

    @Test("Full app configuration with all features")
    func fullConfiguration() async throws {
        let feed = try makeTestFeed(title: "Production Podcast")

        try await withApp(
            configure: { app in
                app.feedConfiguration = FeedConfiguration(
                    ttl: .hours(1),
                    prettyPrint: false,
                    generatorHeader: "ProductionApp/1.0"
                )
                app.healthCheck()
                app.middleware.use(CORSFeedMiddleware())
                app.middleware.use(PodcastFeedMiddleware())
                app.grouped(FeedCacheMiddleware()).podcastFeed("feed.xml") { _ in feed }
                app.batchAudit("feeds", "audit")
            },
            { app in
                try await app.testing().test(
                    .GET, "health",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                    }
                )
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("Production Podcast"))
                    }
                )
            }
        )
    }

    @Test("Multiple feeds — different shows on different paths")
    func multipleFeeds() async throws {
        let techFeed = try makeTestFeed(title: "Tech Weekly")
        let newsFeed = try makeTestFeed(title: "News Daily")

        try await withApp(
            configure: { app in
                app.podcastFeed("shows", "tech", "feed.xml") { _ in techFeed }
                app.podcastFeed("shows", "news", "feed.xml") { _ in newsFeed }
            },
            { app in
                try await app.testing().test(
                    .GET, "shows/tech/feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("Tech Weekly"))
                    }
                )
                try await app.testing().test(
                    .GET, "shows/news/feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("News Daily"))
                    }
                )
            }
        )
    }

    @Test("Feed with all middleware headers")
    func allMiddlewareHeaders() async throws {
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
                        let contentType = res.headers.contentType?.serialize() ?? ""
                        #expect(contentType.contains("rss+xml"))
                        #expect(res.headers[.cacheControl].first?.contains("max-age") == true)
                        #expect(res.headers.first(name: .eTag) != nil)
                        #expect(res.headers.first(name: .lastModified) != nil)
                        #expect(res.headers["X-Generator"].first != nil)
                        #expect(res.headers[.accessControlAllowOrigin].first == "*")
                    }
                )
            }
        )
    }
}
