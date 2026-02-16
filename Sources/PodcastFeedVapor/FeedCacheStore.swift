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
