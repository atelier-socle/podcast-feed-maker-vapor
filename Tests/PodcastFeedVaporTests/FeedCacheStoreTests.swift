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

@testable import PodcastFeedVapor

@Suite("FeedCacheStore — InMemoryFeedCache TTL Tests")
struct FeedCacheStoreTTLTests {

    @Test("TTL boundary — entry expires after TTL seconds")
    func ttlBoundary() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "ttl-1", xml: "<rss/>", ttl: 1)
        // Immediately should be available
        let immediate = try await cache.get(identifier: "ttl-1")
        #expect(immediate == "<rss/>")
        // Wait for expiration
        try await Task.sleep(for: .seconds(1.1))
        let expired = try await cache.get(identifier: "ttl-1")
        #expect(expired == nil)
    }

    @Test("Store empty XML string")
    func storeEmptyXML() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "empty", xml: "", ttl: 60)
        let result = try await cache.get(identifier: "empty")
        #expect(result == "")
    }

    @Test("Store very large XML string")
    func storeVeryLargeXML() async throws {
        let cache = InMemoryFeedCache()
        let xml = String(repeating: "x", count: 1_000_000)
        try await cache.set(identifier: "huge", xml: xml, ttl: 60)
        let result = try await cache.get(identifier: "huge")
        #expect(result?.count == 1_000_000)
    }

    @Test("InvalidateAll with empty cache does not throw")
    func invalidateAllEmpty() async throws {
        let cache = InMemoryFeedCache()
        try await cache.invalidateAll()
        let count = await cache.count
        #expect(count == 0)
    }

    @Test("Expired entry is cleaned up on get")
    func expiredCleanup() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "cleanup", xml: "<rss/>", ttl: 0)
        try await Task.sleep(for: .milliseconds(50))
        let result = try await cache.get(identifier: "cleanup")
        #expect(result == nil)
        // Count should be 0 after cleanup
        let count = await cache.count
        #expect(count == 0)
    }

    @Test("Multiple keys with different TTLs")
    func multipleKeysDifferentTTLs() async throws {
        let cache = InMemoryFeedCache()
        try await cache.set(identifier: "short", xml: "short", ttl: 0)
        try await cache.set(identifier: "long", xml: "long", ttl: 3600)
        try await Task.sleep(for: .milliseconds(50))
        let shortResult = try await cache.get(identifier: "short")
        let longResult = try await cache.get(identifier: "long")
        #expect(shortResult == nil)
        #expect(longResult == "long")
    }
}
