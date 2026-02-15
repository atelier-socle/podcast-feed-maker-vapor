import PodcastFeedMaker
import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Feed Cache Middleware Tests")
struct CacheMiddlewareTests {
    @Test("Adds Cache-Control header to RSS responses")
    func addsCacheControl() async throws {
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
                        #expect(res.headers[.cacheControl].first == "public, max-age=300")
                    }
                )
            }
        )
    }

    @Test("Uses custom TTL when provided")
    func customTTL() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.grouped(FeedCacheMiddleware(ttl: .hours(1))).get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.cacheControl].first == "public, max-age=3600")
                    }
                )
            }
        )
    }

    @Test("Falls back to app config TTL when middleware TTL is nil")
    func fallbackToAppConfig() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.feedConfiguration.ttl = .minutes(10)
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
                        #expect(res.headers[.cacheControl].first == "public, max-age=600")
                    }
                )
            }
        )
    }

    @Test("Does not cache non-RSS responses")
    func doesNotCacheNonRSS() async throws {
        try await withApp(
            configure: { app in
                app.grouped(FeedCacheMiddleware()).get(
                    "api", "data",
                    use: { _ -> [String: String] in
                        ["key": "value"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "api/data",
                    afterResponse: { res in
                        #expect(res.headers.first(name: .eTag) == nil)
                    }
                )
            }
        )
    }
}

@Suite("Feed Cache ETag Tests")
struct CacheETagTests {
    @Test("Adds ETag header to RSS responses")
    func addsETag() async throws {
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
                        let etag = res.headers.first(name: .eTag) ?? ""
                        #expect(etag.hasPrefix("\""))
                        #expect(etag.hasSuffix("\""))
                        #expect(etag.count > 2)
                    }
                )
            }
        )
    }

    @Test("Same content produces same ETag")
    func sameContentSameETag() async throws {
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
                        let secondETag = res.headers.first(name: .eTag) ?? ""
                        #expect(firstETag == secondETag)
                    }
                )
            }
        )
    }

    @Test("Different content produces different ETag")
    func differentContentDifferentETag() async throws {
        let feed1 = try makeTestFeed(title: "Podcast A")
        let feed2 = try makeTestFeed(title: "Podcast B")
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

    @Test("Returns 304 when If-None-Match matches ETag")
    func returns304OnMatchingETag() async throws {
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
                    }
                )
            }
        )
    }

    @Test("304 response has no body")
    func noBodyOn304() async throws {
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
                    }
                )
                try await app.testing().test(
                    .GET, "feed.xml",
                    beforeRequest: { req in
                        req.headers.replaceOrAdd(name: .ifNoneMatch, value: etag)
                    },
                    afterResponse: { res in
                        #expect(res.body.string.isEmpty)
                    }
                )
            }
        )
    }

    @Test("Returns 200 when If-None-Match does not match")
    func returns200OnMismatchedETag() async throws {
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
                    beforeRequest: { req in
                        req.headers.replaceOrAdd(name: .ifNoneMatch, value: "\"wronghash\"")
                    },
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(!res.body.string.isEmpty)
                    }
                )
            }
        )
    }

    @Test("Adds Last-Modified header")
    func addsLastModified() async throws {
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
                        let lastModified = res.headers.first(name: .lastModified) ?? ""
                        #expect(!lastModified.isEmpty)
                        #expect(lastModified.contains("GMT"))
                    }
                )
            }
        )
    }

    @Test("Does not add ETag when disabled")
    func noETagWhenDisabled() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.grouped(FeedCacheMiddleware(enableETag: false)).get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers.first(name: .eTag) == nil)
                    }
                )
            }
        )
    }

    @Test("Does not add Last-Modified when disabled")
    func noLastModifiedWhenDisabled() async throws {
        let feed = try makeTestFeed()
        try await withApp(
            configure: { app in
                app.grouped(FeedCacheMiddleware(enableLastModified: false)).get(
                    "feed.xml",
                    use: { req -> Response in
                        try FeedResponseEncoder.encode(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers.first(name: .lastModified) == nil)
                    }
                )
            }
        )
    }
}
