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
@testable import PodcastFeedVaporRedis

// MARK: - Mock for showcase

/// In-memory implementation of ``FeedCacheStore`` for showcase tests.
/// Demonstrates that any backend can conform to the protocol.
private actor ShowcaseFeedCache: FeedCacheStore {
    private var store: [String: (xml: String, ttl: Int)] = [:]

    func get(identifier: String) async throws -> String? {
        store[identifier]?.xml
    }

    func set(identifier: String, xml: String, ttl: Int) async throws {
        store[identifier] = (xml, ttl)
    }

    func invalidate(identifier: String) async throws {
        store[identifier] = nil
    }

    func invalidateAll() async throws {
        store.removeAll()
    }

    func storedTTL(for identifier: String) -> Int? {
        store[identifier]?.ttl
    }

    var count: Int { store.count }
}

// MARK: - FeedCacheStore Protocol Showcase

@Suite("Redis Showcase — FeedCacheStore Protocol")
struct FeedCacheStoreShowcase {

    @Test("Protocol-based caching — store and retrieve feed XML")
    func storeAndRetrieve() async throws {
        let cache = ShowcaseFeedCache()
        let xml = "<rss><channel><title>My Podcast</title></channel></rss>"
        try await cache.set(identifier: "show-123", xml: xml, ttl: 300)
        let result = try await cache.get(identifier: "show-123")
        #expect(result == xml)
    }

    @Test("Cache miss returns nil")
    func cacheMissReturnsNil() async throws {
        let cache = ShowcaseFeedCache()
        let result = try await cache.get(identifier: "nonexistent")
        #expect(result == nil)
    }

    @Test("Invalidate removes a specific feed")
    func invalidateRemovesFeed() async throws {
        let cache = ShowcaseFeedCache()
        try await cache.set(identifier: "show-1", xml: "<rss/>", ttl: 60)
        try await cache.invalidate(identifier: "show-1")
        let result = try await cache.get(identifier: "show-1")
        #expect(result == nil)
    }

    @Test("InvalidateAll clears entire cache")
    func invalidateAllClearsCache() async throws {
        let cache = ShowcaseFeedCache()
        try await cache.set(identifier: "show-1", xml: "<rss>1</rss>", ttl: 60)
        try await cache.set(identifier: "show-2", xml: "<rss>2</rss>", ttl: 60)
        try await cache.set(identifier: "show-3", xml: "<rss>3</rss>", ttl: 60)
        try await cache.invalidateAll()
        #expect(try await cache.get(identifier: "show-1") == nil)
        #expect(try await cache.get(identifier: "show-2") == nil)
        #expect(try await cache.get(identifier: "show-3") == nil)
    }

    @Test("TTL is stored with cached feed")
    func ttlStoredWithFeed() async throws {
        let cache = ShowcaseFeedCache()
        try await cache.set(identifier: "show-ttl", xml: "<rss/>", ttl: 600)
        let storedTTL = await cache.storedTTL(for: "show-ttl")
        #expect(storedTTL == 600)
    }

    @Test("Custom cache backend — protocol flexibility")
    func protocolFlexibility() async throws {
        let cache: any FeedCacheStore = ShowcaseFeedCache()
        try await cache.set(identifier: "flex-1", xml: "<rss/>", ttl: 120)
        let result = try await cache.get(identifier: "flex-1")
        #expect(result == "<rss/>")
    }
}

// MARK: - RedisFeedCache Configuration Showcase

@Suite("Redis Showcase — RedisFeedCache Configuration")
struct RedisFeedCacheConfigShowcase {

    @Test("Default configuration — prefix 'feed:' and TTL 300")
    func defaultConfig() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let cache: RedisFeedCache = RedisFeedCache(application: app)
                _ = cache
            }
        )
    }

    @Test("Custom configuration — app-specific prefix and TTL")
    func customConfig() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let cache = RedisFeedCache(
                    application: app,
                    keyPrefix: "myapp:feed:",
                    defaultTTL: 600
                )
                _ = cache
            }
        )
    }

    @Test("Application extension — convenience factory")
    func convenienceFactory() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let defaultCache: RedisFeedCache = app.redisFeedCache()
                _ = defaultCache
                let customCache: RedisFeedCache = app.redisFeedCache(
                    keyPrefix: "custom:",
                    defaultTTL: 120
                )
                _ = customCache
            }
        )
    }
}
