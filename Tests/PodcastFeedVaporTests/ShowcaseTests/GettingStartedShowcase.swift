import PodcastFeedMaker
import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Getting Started — Quick Start Guide")
struct GettingStartedShowcase {

    @Test("Minimal setup — configure app, register route, serve XML feed")
    func minimalSetup() async throws {
        let feed = try makeTestFeed(title: "My Podcast")

        try await withApp(
            configure: { app in
                app.podcastFeed("feed.xml") { _ in feed }
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        let contentType = res.headers.contentType?.serialize() ?? ""
                        #expect(contentType.contains("rss+xml"))
                        #expect(res.body.string.contains("<?xml"))
                        #expect(res.body.string.contains("<rss"))
                        #expect(res.body.string.contains("My Podcast"))
                    }
                )
            }
        )
    }

    @Test("Health check — register and verify health endpoint")
    func healthCheck() async throws {
        try await withApp(
            configure: { app in
                app.healthCheck()
            },
            { app in
                try await app.testing().test(
                    .GET, "health",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        let body = res.body.string
                        #expect(body.contains("\"status\":\"ok\""))
                        #expect(body.contains("\"version\":\"0.1.0\""))
                        #expect(body.contains("\"uptime\":"))
                    }
                )
            }
        )
    }

    @Test("Custom configuration — TTL, generator header, pretty print")
    func customConfiguration() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.feedConfiguration = FeedConfiguration(
                    ttl: .hours(1),
                    prettyPrint: true,
                    generatorHeader: "MyApp/1.0"
                )
                app.podcastFeed("feed.xml") { _ in feed }
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.cacheControl].first == "public, max-age=3600")
                        #expect(res.headers["X-Generator"].first == "MyApp/1.0")
                        #expect(res.body.string.contains("\n"))
                    }
                )
            }
        )
    }

    @Test("Feed response convenience — req.feedResponse() shorthand")
    func feedResponseConvenience() async throws {
        let feed = try makeTestFeed(title: "Shorthand Podcast")

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try req.feedResponse(feed)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        let contentType = res.headers.contentType?.serialize() ?? ""
                        #expect(contentType.contains("rss+xml"))
                        #expect(res.body.string.contains("Shorthand Podcast"))
                    }
                )
            }
        )
    }

    @Test("XML response factory — Response.xml() for raw XML strings")
    func xmlResponseFactory() async throws {
        let rawXML = "<?xml version=\"1.0\"?><rss><channel><title>Raw</title></channel></rss>"

        try await withApp(
            configure: { app in
                app.get(
                    "raw.xml",
                    use: { _ -> Response in
                        Response.xml(rawXML)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "raw.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        let contentType = res.headers.contentType?.serialize() ?? ""
                        #expect(contentType.contains("rss+xml"))
                        #expect(res.body.string == rawXML)
                    }
                )
            }
        )
    }
}
