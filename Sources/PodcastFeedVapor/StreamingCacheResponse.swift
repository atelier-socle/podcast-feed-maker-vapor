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

import Crypto
import PodcastFeedMaker
import Vapor

/// Creates a streaming HTTP response with cache-through behavior.
///
/// On the first request (cache miss), the feed XML is streamed to the client
/// while simultaneously buffered. Once streaming completes, the full XML is
/// stored in the cache. Subsequent requests (cache hit) serve directly from
/// the cache as a standard response with ETag support.
///
/// ```swift
/// let cache = InMemoryFeedCache()
///
/// app.get("large-feed.xml") { req -> Response in
///     let feed = try await loadLargeFeed(on: req.db)
///     return try await StreamingCacheResponse.stream(
///         feed,
///         for: req,
///         cache: cache,
///         identifier: "show-123",
///         ttl: .hours(1)
///     )
/// }
/// ```
public struct StreamingCacheResponse: Sendable {

    /// Creates a streaming response with cache-through caching.
    ///
    /// - Parameters:
    ///   - feed: The podcast feed to serve.
    ///   - request: The Vapor request (for configuration and conditional request headers).
    ///   - cache: The cache store backend.
    ///   - identifier: Unique cache key for this feed.
    ///   - ttl: Cache duration. Defaults to `nil` (uses app's `feedConfiguration.ttl`).
    /// - Returns: An HTTP response — either from cache (with ETag/304) or streamed.
    public static func stream(
        _ feed: PodcastFeed,
        for request: Request,
        cache: any FeedCacheStore,
        identifier: String,
        ttl: CacheControlDuration? = nil
    ) async throws -> Response {
        let config = request.application.feedConfiguration
        let effectiveTTL = ttl ?? config.ttl

        // 1. Check cache
        if let cached = try await cache.get(identifier: identifier) {
            return buildCachedResponse(
                xml: cached,
                config: config,
                ttl: effectiveTTL,
                request: request
            )
        }

        // 2. Cache miss — stream and capture
        let generator = StreamingFeedGenerator(prettyPrint: config.prettyPrint)

        let response = Response(status: .ok)
        response.headers.contentType = config.contentType
        if let generatorName = config.generatorHeader {
            response.headers.add(name: "X-Generator", value: generatorName)
        }
        response.headers.add(
            name: .cacheControl,
            value: "public, max-age=\(effectiveTTL.totalSeconds)"
        )

        // Use a reference type to capture XML chunks during streaming
        let collector = XMLCollector()

        response.body = .init(managedAsyncStream: { writer in
            for try await chunk in generator.generate(feed) {
                await collector.append(chunk)
                try await writer.writeBuffer(ByteBuffer(string: chunk))
            }

            // Store complete XML in cache after streaming finishes
            let fullXML = await collector.result
            try? await cache.set(
                identifier: identifier,
                xml: fullXML,
                ttl: effectiveTTL.totalSeconds
            )
        })

        return response
    }

    /// Builds a standard response from cached XML with ETag and 304 support.
    private static func buildCachedResponse(
        xml: String,
        config: FeedConfiguration,
        ttl: CacheControlDuration,
        request: Request
    ) -> Response {
        let hash = SHA256.hash(data: Data(xml.utf8))
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        let etag = "\"\(hex)\""

        // Check for conditional request (304 Not Modified)
        if let clientETag = request.headers.first(name: .ifNoneMatch),
            clientETag == etag
        {
            let notModified = Response(status: .notModified)
            notModified.headers.replaceOrAdd(name: .eTag, value: etag)
            notModified.headers.replaceOrAdd(
                name: .cacheControl,
                value: "public, max-age=\(ttl.totalSeconds)"
            )
            return notModified
        }

        let response = Response(status: .ok)
        response.headers.contentType = config.contentType

        if let generatorName = config.generatorHeader {
            response.headers.add(name: "X-Generator", value: generatorName)
        }

        response.headers.replaceOrAdd(name: .eTag, value: etag)
        response.headers.replaceOrAdd(
            name: .cacheControl,
            value: "public, max-age=\(ttl.totalSeconds)"
        )
        response.body = .init(string: xml)
        return response
    }
}

/// Thread-safe collector for XML chunks during streaming.
public actor XMLCollector {
    private var chunks: [String] = []

    /// Creates a new XML collector.
    public init() {}

    /// Appends a chunk to the buffer.
    public func append(_ chunk: String) {
        chunks.append(chunk)
    }

    /// Returns the concatenated XML string.
    public var result: String {
        chunks.joined()
    }
}
