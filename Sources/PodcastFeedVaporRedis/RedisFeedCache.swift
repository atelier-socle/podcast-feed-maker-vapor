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

import PodcastFeedVapor
import Redis
import Vapor

/// Redis-backed implementation of `FeedCacheStore`.
///
/// Caches generated podcast feed XML in Redis with configurable TTL.
/// Uses Vapor's Redis integration for connection pooling and async/await support.
///
/// ```swift
/// import PodcastFeedVaporRedis
///
/// // In configure.swift
/// app.redis.configuration = try RedisConfiguration(hostname: "localhost")
///
/// let cache = RedisFeedCache(
///     application: app,
///     keyPrefix: "podcast:feed:",
///     defaultTTL: 300  // 5 minutes
/// )
///
/// // Store generated XML
/// try await cache.set(identifier: "show-123", xml: feedXML, ttl: 600)
///
/// // Retrieve cached XML
/// if let cached = try await cache.get(identifier: "show-123") {
///     return cached  // Cache hit — skip regeneration
/// }
///
/// // Invalidate when feed content changes
/// try await cache.invalidate(identifier: "show-123")
/// ```
public struct RedisFeedCache: FeedCacheStore, Sendable {
    private let application: Application
    private let keyPrefix: String
    private let defaultTTL: Int

    /// Creates a new Redis feed cache.
    ///
    /// - Parameters:
    ///   - application: The Vapor Application (provides Redis connection pool).
    ///   - keyPrefix: Prefix for all Redis keys (default: `"feed:"`).
    ///   - defaultTTL: Default time-to-live in seconds (default: `300` = 5 min).
    public init(
        application: Application,
        keyPrefix: String = "feed:",
        defaultTTL: Int = 300
    ) {
        self.application = application
        self.keyPrefix = keyPrefix
        self.defaultTTL = defaultTTL
    }

    // MARK: - FeedCacheStore

    public func get(identifier: String) async throws -> String? {
        let key = RedisKey(keyPrefix + identifier)
        return try await application.redis.get(key, as: String.self).get()
    }

    public func set(identifier: String, xml: String, ttl: Int) async throws {
        let key = RedisKey(keyPrefix + identifier)
        let effectiveTTL = ttl > 0 ? ttl : defaultTTL
        try await application.redis.setex(key, to: xml, expirationInSeconds: effectiveTTL).get()
    }

    /// Store feed XML using the default TTL.
    ///
    /// - Parameters:
    ///   - identifier: The feed identifier.
    ///   - xml: The XML string to cache.
    public func set(identifier: String, xml: String) async throws {
        try await set(identifier: identifier, xml: xml, ttl: defaultTTL)
    }

    public func invalidate(identifier: String) async throws {
        let key = RedisKey(keyPrefix + identifier)
        _ = try await application.redis.delete(key).get()
    }

    public func invalidateAll() async throws {
        let pattern = keyPrefix + "*"
        var cursor = 0
        repeat {
            let (nextCursor, keys) = try await application.redis.scan(
                startingFrom: cursor,
                matching: pattern
            ).get()
            cursor = nextCursor
            if !keys.isEmpty {
                let redisKeys = keys.map { RedisKey($0) }
                _ = try await application.redis.delete(redisKeys).get()
            }
        } while cursor != 0
    }
}

// MARK: - Application Extension

extension Application {
    /// Convenience to create a Redis feed cache from the application.
    ///
    /// ```swift
    /// let cache = app.redisFeedCache(keyPrefix: "myapp:feed:", defaultTTL: 600)
    /// ```
    public func redisFeedCache(
        keyPrefix: String = "feed:",
        defaultTTL: Int = 300
    ) -> RedisFeedCache {
        RedisFeedCache(
            application: self,
            keyPrefix: keyPrefix,
            defaultTTL: defaultTTL
        )
    }
}
