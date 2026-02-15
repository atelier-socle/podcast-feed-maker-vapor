import PodcastFeedMaker
import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Streaming Feed Response Tests")
struct StreamingResponseTests {
    @Test("Streams feed as XML response")
    func streamsXML() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingFeedResponse.stream(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("<?xml"))
                        #expect(res.body.string.contains("<rss"))
                    }
                )
            }
        )
    }

    @Test("Streaming response has correct Content-Type")
    func correctContentType() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingFeedResponse.stream(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let contentType = res.headers.contentType?.serialize() ?? ""
                        #expect(contentType.contains("rss+xml"))
                    }
                )
            }
        )
    }

    @Test("Streaming response includes X-Generator header")
    func includesGeneratorHeader() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingFeedResponse.stream(feed, for: req)
                    })
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

    @Test("Streamed XML is valid and parseable")
    func validXML() async throws {
        let feed = try makeTestFeed(title: "Stream Test Podcast")
        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingFeedResponse.stream(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let xml = res.body.string
                        #expect(xml.contains("<title>Stream Test Podcast</title>"))
                        #expect(xml.contains("</rss>"))
                    }
                )
            }
        )
    }

    @Test("Streaming large feed works")
    func largeFeed() async throws {
        let feed = try makeTestFeed(title: "Large Podcast", itemCount: 100)
        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingFeedResponse.stream(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("Episode 1"))
                        #expect(res.body.string.contains("Episode 100"))
                    }
                )
            }
        )
    }
}
