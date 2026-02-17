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

/// Protocol for feed cache storage backends.
///
/// Allows swapping between Redis, in-memory, or custom implementations.
/// The core library provides the protocol; backends like `RedisFeedCache`
/// implement it in optional targets.
///
/// ```swift
/// // In-memory cache for development
/// actor InMemoryFeedCache: FeedCacheStore {
///     private var store: [String: String] = [:]
///
///     func get(identifier: String) async throws -> String? {
///         store[identifier]
///     }
///
///     func set(identifier: String, xml: String, ttl: Int) async throws {
///         store[identifier] = xml
///     }
///
///     func invalidate(identifier: String) async throws {
///         store[identifier] = nil
///     }
///
///     func invalidateAll() async throws {
///         store.removeAll()
///     }
/// }
/// ```
public protocol FeedCacheStore: Sendable {
    /// Retrieve cached feed XML for the given identifier.
    func get(identifier: String) async throws -> String?

    /// Store feed XML with a TTL (time-to-live) in seconds.
    func set(identifier: String, xml: String, ttl: Int) async throws

    /// Remove a specific cached feed.
    func invalidate(identifier: String) async throws

    /// Remove all cached feeds matching the prefix.
    func invalidateAll() async throws
}
