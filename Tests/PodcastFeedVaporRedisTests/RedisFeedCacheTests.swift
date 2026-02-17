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

// MARK: - InMemory Mock

/// In-memory implementation of ``FeedCacheStore`` for testing.
private actor InMemoryFeedCache: FeedCacheStore {
    private var storage: [String: String] = [:]

    func get(identifier: String) async throws -> String? {
        storage[identifier]
    }

    func set(identifier: String, xml: String, ttl: Int) async throws {
        storage[identifier] = xml
    }

    func invalidate(identifier: String) async throws {
        storage.removeValue(forKey: identifier)
    }

    func invalidateAll() async throws {
        storage.removeAll()
    }

    var count: Int { storage.count }
}

// MARK: - Protocol Tests

@Suite("FeedCacheStore Protocol Tests")
struct FeedCacheStoreProtocolTests {

    @Test("FeedCacheStore protocol compiles with all 4 required methods")
    func protocolCompiles() async throws {
        let cache: any FeedCacheStore = InMemoryFeedCache()
        _ = try await cache.get(identifier: "test")
        try await cache.set(identifier: "test", xml: "<rss/>", ttl: 60)
        try await cache.invalidate(identifier: "test")
        try await cache.invalidateAll()
    }

    @Test("InMemory mock — get returns nil for missing key")
    func getMissingKey() async throws {
        let cache = InMemoryFeedCache()
        let result = try await cache.get(identifier: "nonexistent")
        #expect(result == nil)
    }

    @Test("InMemory mock — set then get returns stored value")
    func setThenGet() async throws {
        let cache = InMemoryFeedCache()
        let xml = "<rss><channel><title>Test</title></channel></rss>"
        try await cache.set(identifier: "show-1", xml: xml, ttl: 300)
        let result = try await cache.get(identifier: "show-1")
        #expect(result == xml)
    }

    @Test("InMemory mock — invalidate removes entry")
    func invalidateRemovesEntry() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "show-1", xml: "<rss/>", ttl: 60)
        try await cache.invalidate(identifier: "show-1")
        let result = try await cache.get(identifier: "show-1")
        #expect(result == nil)
    }

    @Test("InMemory mock — invalidateAll clears everything")
    func invalidateAllClears() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "show-1", xml: "<rss/>", ttl: 60)
        try await cache.set(identifier: "show-2", xml: "<rss/>", ttl: 60)
        try await cache.invalidateAll()
        let count = await cache.count
        #expect(count == 0)
    }

    @Test("InMemory mock — multiple keys are independent")
    func multipleKeysIndependent() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "a", xml: "xml-a", ttl: 60)
        try await cache.set(identifier: "b", xml: "xml-b", ttl: 60)
        #expect(try await cache.get(identifier: "a") == "xml-a")
        #expect(try await cache.get(identifier: "b") == "xml-b")
        try await cache.invalidate(identifier: "a")
        #expect(try await cache.get(identifier: "a") == nil)
        #expect(try await cache.get(identifier: "b") == "xml-b")
    }
}

// MARK: - RedisFeedCache Construction Tests

@Suite("RedisFeedCache Construction Tests")
struct RedisFeedCacheConstructionTests {

    @Test("RedisFeedCache initializes with default values")
    func defaultInit() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let cache = RedisFeedCache(application: app)
                _ = cache
            }
        )
    }

    @Test("RedisFeedCache initializes with custom values")
    func customInit() async throws {
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

    @Test("Application extension creates cache with defaults")
    func extensionDefaults() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let cache: RedisFeedCache = app.redisFeedCache()
                _ = cache
            }
        )
    }

    @Test("Application extension creates cache with custom values")
    func extensionCustom() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let cache: RedisFeedCache = app.redisFeedCache(keyPrefix: "custom:", defaultTTL: 600)
                _ = cache
            }
        )
    }
}
