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
import Foundation
import Vapor

/// HTTP caching middleware for podcast feed responses.
///
/// Adds ETag (SHA256 of response body), Last-Modified, and Cache-Control headers
/// to responses. Returns 304 Not Modified when the client's cached version is still valid.
///
/// ```swift
/// app.middleware.use(FeedCacheMiddleware())
///
/// // Custom TTL
/// app.middleware.use(FeedCacheMiddleware(ttl: .hours(1)))
///
/// // Selective features
/// app.middleware.use(FeedCacheMiddleware(
///     ttl: .minutes(15),
///     enableETag: true,
///     enableLastModified: false
/// ))
/// ```
public struct FeedCacheMiddleware: AsyncMiddleware, Sendable {
    /// Cache TTL for the Cache-Control max-age directive.
    /// If `nil`, uses the application's `feedConfiguration.ttl`.
    private let ttl: CacheControlDuration?

    /// Whether to compute and add ETag headers.
    private let enableETag: Bool

    /// Whether to add Last-Modified headers.
    private let enableLastModified: Bool

    /// Creates a new feed cache middleware.
    ///
    /// - Parameters:
    ///   - ttl: Cache duration. Defaults to `nil` (uses app's `feedConfiguration.ttl`).
    ///   - enableETag: Whether to add ETag headers. Defaults to `true`.
    ///   - enableLastModified: Whether to add Last-Modified headers. Defaults to `true`.
    public init(
        ttl: CacheControlDuration? = nil,
        enableETag: Bool = true,
        enableLastModified: Bool = true
    ) {
        self.ttl = ttl
        self.enableETag = enableETag
        self.enableLastModified = enableLastModified
    }

    /// Processes the request, adding HTTP caching headers to RSS/XML responses.
    ///
    /// - Parameters:
    ///   - request: The incoming request.
    ///   - next: The next responder in the chain.
    /// - Returns: The response with caching headers, or 304 Not Modified.
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)

        guard let contentType = response.headers.contentType,
            contentType.subType.contains("rss") || contentType.subType.contains("xml")
        else {
            return response
        }

        let effectiveTTL = ttl ?? request.application.feedConfiguration.ttl

        response.headers.replaceOrAdd(
            name: .cacheControl,
            value: "public, max-age=\(effectiveTTL.totalSeconds)"
        )

        if enableETag {
            guard let bodyData = response.body.data else {
                return response
            }

            let hash = SHA256.hash(data: bodyData)
            let hex = hash.map { String(format: "%02x", $0) }.joined()
            let etag = "\"\(hex)\""

            if let clientETag = request.headers.first(name: .ifNoneMatch),
                clientETag == etag
            {
                let notModified = Response(status: .notModified)
                notModified.headers.replaceOrAdd(name: .eTag, value: etag)
                notModified.headers.replaceOrAdd(
                    name: .cacheControl,
                    value: "public, max-age=\(effectiveTTL.totalSeconds)"
                )
                return notModified
            }

            response.headers.replaceOrAdd(name: .eTag, value: etag)
        }

        if enableLastModified {
            let formatted = Self.httpDateString(from: Date())
            response.headers.replaceOrAdd(name: .lastModified, value: formatted)
        }

        return response
    }

    /// Formats a `Date` as an RFC 7231 HTTP date string.
    ///
    /// Example: `"Sun, 06 Nov 1994 08:49:37 GMT"`
    private static func httpDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        return formatter.string(from: date)
    }
}
