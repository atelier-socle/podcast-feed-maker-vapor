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

import Vapor

/// Pagination parameters extracted from request query strings.
///
/// Supports `?limit=N&offset=M` query parameters for paginating episode lists.
///
/// ```swift
/// app.podcastFeed("feed.xml") { req in
///     let pagination = FeedPagination(from: req, defaultLimit: 50, maxLimit: 200)
///     let episodes = try await Episode.query(on: req.db)
///         .sort(\.$pubDate, .descending)
///         .offset(pagination.offset)
///         .limit(pagination.limit)
///         .all()
///     return buildFeed(episodes: episodes)
/// }
/// ```
public struct FeedPagination: Sendable, Equatable {
    /// Number of items to return.
    public let limit: Int

    /// Number of items to skip.
    public let offset: Int

    /// Default page limit when not specified in query.
    public static let defaultLimit = 50

    /// Maximum allowed limit to prevent abuse.
    public static let maxLimit = 1000

    /// Creates pagination from a Vapor request's query parameters.
    ///
    /// - Parameters:
    ///   - request: The incoming Vapor request.
    ///   - defaultLimit: Default number of items if `limit` is not in the query. Defaults to 50.
    ///   - maxLimit: Maximum allowed limit. Defaults to 1000.
    public init(
        from request: Request,
        defaultLimit: Int = FeedPagination.defaultLimit,
        maxLimit: Int = FeedPagination.maxLimit
    ) {
        let rawLimit = (try? request.query.get(Int.self, at: "limit")) ?? defaultLimit
        self.limit = max(1, min(rawLimit, maxLimit))
        let rawOffset = (try? request.query.get(Int.self, at: "offset")) ?? 0
        self.offset = max(0, rawOffset)
    }

    /// Creates pagination with explicit values (useful for testing).
    ///
    /// - Parameters:
    ///   - limit: Number of items.
    ///   - offset: Number of items to skip.
    public init(limit: Int, offset: Int) {
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}
