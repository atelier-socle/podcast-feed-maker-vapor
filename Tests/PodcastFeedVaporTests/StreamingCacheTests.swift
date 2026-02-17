// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Atelier Socle SAS
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
import VaporTesting

@testable import PodcastFeedVapor

// MARK: - XMLCollector Tests

@Suite("XMLCollector Tests")
struct XMLCollectorTests {

    @Test("Empty collector returns empty string")
    func emptyCollector() async {
        let collector = XMLCollector()
        let result = await collector.result
        #expect(result == "")
    }

    @Test("Single chunk")
    func singleChunk() async {
        let collector = XMLCollector()
        await collector.append("<rss/>")
        let result = await collector.result
        #expect(result == "<rss/>")
    }

    @Test("Multiple chunks concatenated in order")
    func multipleChunks() async {
        let collector = XMLCollector()
        await collector.append("<?xml?>")
        await collector.append("<rss>")
        await collector.append("<channel/>")
        await collector.append("</rss>")
        let result = await collector.result
        #expect(result == "<?xml?><rss><channel/></rss>")
    }
}

// MARK: - InMemoryFeedCache Edge Cases

@Suite("InMemoryFeedCache Edge Cases")
struct InMemoryFeedCacheEdgeCases {

    @Test("Overwrite existing key")
    func overwriteKey() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "key", xml: "old", ttl: 60)
        try await cache.set(identifier: "key", xml: "new", ttl: 60)
        let result = try await cache.get(identifier: "key")
        #expect(result == "new")
    }

    @Test("Invalidate non-existent key does not throw")
    func invalidateNonExistent() async throws {
        let cache = InMemoryFeedCache()
        try await cache.invalidate(identifier: "ghost")
        let count = await cache.count
        #expect(count == 0)
    }

    @Test("InvalidateAll with empty cache")
    func invalidateAllEmpty() async throws {
        let cache = InMemoryFeedCache()
        try await cache.invalidateAll()
        let count = await cache.count
        #expect(count == 0)
    }

    @Test("Store empty string")
    func storeEmptyString() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "empty", xml: "", ttl: 60)
        let result = try await cache.get(identifier: "empty")
        #expect(result == "")
    }

    @Test("Store large string")
    func storeLargeString() async throws {
        let cache = InMemoryFeedCache()
        let largeXML = String(repeating: "<item/>", count: 10_000)
        try await cache.set(identifier: "large", xml: largeXML, ttl: 60)
        let result = try await cache.get(identifier: "large")
        #expect(result == largeXML)
    }

    @Test("Concurrent access")
    func concurrentAccess() async throws {
        let cache = InMemoryFeedCache()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    try? await cache.set(identifier: "key-\(i)", xml: "xml-\(i)", ttl: 60)
                }
            }
        }
        let count = await cache.count
        #expect(count == 50)
    }
}

// MARK: - StreamingCacheResponse Header Tests

@Suite("StreamingCacheResponse Header Tests")
struct StreamingCacheResponseHeaderTests {

    @Test("Cache miss — Content-Type is RSS XML")
    func cacheMissContentType() async throws {
        let feed = try makeTestFeed()
        let cache = InMemoryFeedCache()

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingCacheResponse.stream(
                            feed, for: req, cache: cache, identifier: "ct-test"
                        )
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

    @Test("Cache hit — ETag present on cached response")
    func cacheHitETag() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "etag-test", xml: "<rss/>", ttl: 3600)
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingCacheResponse.stream(
                            feed, for: req, cache: cache, identifier: "etag-test"
                        )
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let etag = res.headers.first(name: .eTag) ?? ""
                        #expect(!etag.isEmpty)
                        #expect(etag.hasPrefix("\""))
                        #expect(etag.hasSuffix("\""))
                    }
                )
            }
        )
    }

    @Test("Cache hit — X-Generator header present")
    func cacheHitGeneratorHeader() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "gen-test", xml: "<rss/>", ttl: 3600)
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.feedConfiguration.generatorHeader = "CacheApp/2.0"
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingCacheResponse.stream(
                            feed, for: req, cache: cache, identifier: "gen-test"
                        )
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers["X-Generator"].first == "CacheApp/2.0")
                    }
                )
            }
        )
    }
}
