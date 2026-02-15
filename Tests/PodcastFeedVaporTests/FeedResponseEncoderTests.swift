import PodcastFeedMaker
import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Feed Response Encoder Tests")
struct FeedResponseEncoderTests {
    @Test("Encodes feed to XML with correct Content-Type")
    func encodeFeedContentType() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
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
                    }
                )
            }
        )
    }

    @Test("Includes X-Generator header by default")
    func defaultGeneratorHeader() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let generator = res.headers["X-Generator"]
                        #expect(generator.first == "PodcastFeedMaker")
                    }
                )
            }
        )
    }

    @Test("Omits X-Generator when configured to nil")
    func noGeneratorHeader() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.feedConfiguration.generatorHeader = nil
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
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

    @Test("Includes Cache-Control header with correct max-age")
    func cacheControlHeader() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let cacheControl = res.headers[.cacheControl]
                        #expect(cacheControl.first == "public, max-age=300")
                    }
                )
            }
        )
    }

    @Test("Pretty-print produces indented XML")
    func prettyPrintXML() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.feedConfiguration.prettyPrint = true
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.body.string.contains("\t"))
                    }
                )
            }
        )
    }

    @Test("Minified XML has no unnecessary whitespace")
    func minifiedXML() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.feedConfiguration.prettyPrint = false
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(!res.body.string.contains("\t"))
                    }
                )
            }
        )
    }
}
