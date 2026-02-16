import Foundation

/// In-memory implementation of ``FeedCacheStore`` for development and testing.
///
/// Stores cached feed XML in a dictionary with optional TTL expiration.
/// Not suitable for production multi-instance deployments — use
/// `RedisFeedCache` (from `PodcastFeedVaporRedis`) for that.
///
/// ```swift
/// let cache = InMemoryFeedCache()
///
/// // Store generated XML
/// try await cache.set(identifier: "show-123", xml: feedXML, ttl: 300)
///
/// // Retrieve from cache
/// if let cached = try await cache.get(identifier: "show-123") {
///     return cached  // Cache hit
/// }
/// ```
public actor InMemoryFeedCache: FeedCacheStore {
    private var store: [String: CacheEntry] = [:]

    private struct CacheEntry {
        let xml: String
        let expiresAt: Date
    }

    /// Creates a new in-memory feed cache.
    public init() {}

    public func get(identifier: String) async throws -> String? {
        guard let entry = store[identifier] else { return nil }
        if Date() > entry.expiresAt {
            store[identifier] = nil
            return nil
        }
        return entry.xml
    }

    public func set(identifier: String, xml: String, ttl: Int) async throws {
        let expiresAt = Date().addingTimeInterval(TimeInterval(ttl))
        store[identifier] = CacheEntry(xml: xml, expiresAt: expiresAt)
    }

    public func invalidate(identifier: String) async throws {
        store[identifier] = nil
    }

    public func invalidateAll() async throws {
        store.removeAll()
    }

    /// Returns the number of entries currently in the cache (including expired).
    /// Useful for testing.
    public var count: Int {
        store.count
    }
}
