import PodcastFeedMaker
import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Streaming Cache — Stream-Through Caching")
struct StreamingCacheShowcase {

    @Test("Cache miss — first request streams and caches XML")
    func cacheMissStreamsAndCaches() async throws {
        let feed = try makeTestFeed(title: "Cache Test Podcast", itemCount: 10)
        let cache = InMemoryFeedCache()

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingCacheResponse.stream(
                            feed, for: req, cache: cache, identifier: "test-feed"
                        )
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("Cache Test Podcast"))
                        let contentType = res.headers.contentType?.serialize() ?? ""
                        #expect(contentType.contains("rss+xml"))
                    }
                )

                // Verify XML was cached
                let cached = try await cache.get(identifier: "test-feed")
                #expect(cached != nil)
                #expect(cached?.contains("Cache Test Podcast") == true)
            }
        )
    }

    @Test("Cache hit — second request serves from cache")
    func cacheHitServesFromCache() async throws {
        let cache = InMemoryFeedCache()
        let cachedXML = "<?xml version=\"1.0\"?><rss><channel><title>Cached Pod</title></channel></rss>"
        try await cache.set(identifier: "cached-feed", xml: cachedXML, ttl: 3600)

        // Feed that would generate DIFFERENT XML — proves we're reading from cache
        let differentFeed = try makeTestFeed(title: "Different Title")

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingCacheResponse.stream(
                            differentFeed, for: req, cache: cache, identifier: "cached-feed"
                        )
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        // Should serve cached XML, not the different feed
                        #expect(res.body.string.contains("Cached Pod"))
                        #expect(!res.body.string.contains("Different Title"))
                    }
                )
            }
        )
    }

    @Test("Cache hit with ETag — returns 304 Not Modified")
    func cacheHitWith304() async throws {
        let cache = InMemoryFeedCache()
        let cachedXML = "<?xml version=\"1.0\"?><rss><channel><title>ETag Pod</title></channel></rss>"
        try await cache.set(identifier: "etag-feed", xml: cachedXML, ttl: 3600)

        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingCacheResponse.stream(
                            feed, for: req, cache: cache, identifier: "etag-feed"
                        )
                    })
            },
            { app in
                // First request — get ETag
                var etag = ""
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        etag = res.headers.first(name: .eTag) ?? ""
                        #expect(!etag.isEmpty)
                    }
                )

                // Second request with If-None-Match — 304
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

    @Test("Custom TTL — Cache-Control reflects custom duration")
    func customTTL() async throws {
        let feed = try makeTestFeed()
        let cache = InMemoryFeedCache()

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingCacheResponse.stream(
                            feed, for: req, cache: cache, identifier: "ttl-feed",
                            ttl: .minutes(30)
                        )
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.cacheControl].first == "public, max-age=1800")
                    }
                )
            }
        )
    }

    @Test("Default TTL — uses app feedConfiguration.ttl")
    func defaultTTL() async throws {
        let feed = try makeTestFeed()
        let cache = InMemoryFeedCache()

        try await withApp(
            configure: { app in
                app.feedConfiguration.ttl = .hours(2)
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingCacheResponse.stream(
                            feed, for: req, cache: cache, identifier: "default-ttl"
                        )
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.cacheControl].first == "public, max-age=7200")
                    }
                )
            }
        )
    }

    @Test("X-Generator header present on streamed response")
    func generatorHeaderOnStream() async throws {
        let feed = try makeTestFeed()
        let cache = InMemoryFeedCache()

        try await withApp(
            configure: { app in
                app.feedConfiguration.generatorHeader = "TestApp/1.0"
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingCacheResponse.stream(
                            feed, for: req, cache: cache, identifier: "gen-header"
                        )
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers["X-Generator"].first == "TestApp/1.0")
                    }
                )
            }
        )
    }

    @Test("Large feed — streaming cache handles 100+ episodes")
    func largeFeedStreamingCache() async throws {
        let feed = try makeTestFeed(title: "Large Cached Podcast", itemCount: 100)
        let cache = InMemoryFeedCache()

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingCacheResponse.stream(
                            feed, for: req, cache: cache, identifier: "large-feed"
                        )
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

                let cached = try await cache.get(identifier: "large-feed")
                #expect(cached != nil)
                #expect(cached?.contains("Episode 100") == true)
            }
        )
    }

    @Test("Cache invalidation — invalidate removes cached feed")
    func cacheInvalidation() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "stale", xml: "<rss/>", ttl: 3600)
        try await cache.invalidate(identifier: "stale")
        let result = try await cache.get(identifier: "stale")
        #expect(result == nil)
    }

    @Test("Cache invalidateAll — clears all entries")
    func cacheInvalidateAll() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "feed-1", xml: "<rss>1</rss>", ttl: 3600)
        try await cache.set(identifier: "feed-2", xml: "<rss>2</rss>", ttl: 3600)
        try await cache.invalidateAll()
        #expect(try await cache.get(identifier: "feed-1") == nil)
        #expect(try await cache.get(identifier: "feed-2") == nil)
    }

    @Test("Streamed XML is valid and parseable after caching")
    func streamedXMLParseableAfterCaching() async throws {
        let feed = try makeTestFeed(title: "Parseable Cached")
        let cache = InMemoryFeedCache()

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingCacheResponse.stream(
                            feed, for: req, cache: cache, identifier: "parse-test"
                        )
                    })
            },
            { app in
                try await app.testing().test(.GET, "feed.xml", afterResponse: { _ in })

                let cached = try await cache.get(identifier: "parse-test")
                let xml = try #require(cached)
                #expect(xml.contains("<?xml"))
                #expect(xml.contains("<rss"))
                #expect(xml.contains("</rss>"))
                #expect(xml.contains("Parseable Cached"))

                // Verify it's parseable by FeedParser
                let parser = FeedParser()
                let parsed = try parser.parse(xml)
                #expect(parsed.channel?.title == "Parseable Cached")
            }
        )
    }
}

@Suite("Streaming Cache — InMemoryFeedCache")
struct InMemoryCacheShowcase {

    @Test("Store and retrieve — basic cache operations")
    func storeAndRetrieve() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "test", xml: "<rss/>", ttl: 300)
        let result = try await cache.get(identifier: "test")
        #expect(result == "<rss/>")
    }

    @Test("Cache miss — returns nil for unknown identifier")
    func cacheMiss() async throws {
        let cache = InMemoryFeedCache()
        let result = try await cache.get(identifier: "nonexistent")
        #expect(result == nil)
    }

    @Test("TTL expiration — expired entries return nil")
    func ttlExpiration() async throws {
        let cache = InMemoryFeedCache()
        // TTL of 0 means already expired
        try await cache.set(identifier: "expired", xml: "<rss/>", ttl: 0)
        // Small delay to ensure expiration
        try await Task.sleep(for: .milliseconds(50))
        let result = try await cache.get(identifier: "expired")
        #expect(result == nil)
    }

    @Test("FeedCacheStore protocol conformance — type erasure works")
    func protocolConformance() async throws {
        let cache: any FeedCacheStore = InMemoryFeedCache()
        try await cache.set(identifier: "proto", xml: "<rss/>", ttl: 60)
        let result = try await cache.get(identifier: "proto")
        #expect(result == "<rss/>")
    }

    @Test("Count — tracks number of entries")
    func countTracking() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "a", xml: "1", ttl: 60)
        try await cache.set(identifier: "b", xml: "2", ttl: 60)
        let count = await cache.count
        #expect(count == 2)
    }
}

@Suite("Streaming Cache — FeedCacheStore Protocol")
struct FeedCacheStoreProtocolShowcase {

    @Test("Protocol defines four required methods")
    func protocolRequirements() async throws {
        // Verify the protocol can be used as existential type
        let cache: any FeedCacheStore = InMemoryFeedCache()
        try await cache.set(identifier: "test", xml: "<rss/>", ttl: 60)
        _ = try await cache.get(identifier: "test")
        try await cache.invalidate(identifier: "test")
        try await cache.invalidateAll()
    }

    @Test("Custom backend — actor-based implementation")
    func customBackend() async throws {
        // Demonstrates that any actor/class/struct can conform
        actor CustomCache: FeedCacheStore {
            private var data: [String: String] = [:]

            func get(identifier: String) async throws -> String? { data[identifier] }
            func set(identifier: String, xml: String, ttl: Int) async throws { data[identifier] = xml }
            func invalidate(identifier: String) async throws { data[identifier] = nil }
            func invalidateAll() async throws { data.removeAll() }
        }

        let cache = CustomCache()
        try await cache.set(identifier: "custom", xml: "<rss/>", ttl: 60)
        let result = try await cache.get(identifier: "custom")
        #expect(result == "<rss/>")
    }
}
