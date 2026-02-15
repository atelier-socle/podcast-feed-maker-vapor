import PodcastFeedMaker
import Vapor

/// Configuration for the PodcastFeedVapor middleware stack.
///
/// Controls XML generation, caching, compression, and response headers.
///
/// ```swift
/// let config = FeedConfiguration(
///     ttl: .minutes(5),
///     gzipEnabled: true,
///     prettyPrint: false,
///     generatorHeader: "PodcastFeedMaker"
/// )
/// app.feedConfiguration = config
/// ```
public struct FeedConfiguration: Sendable {
    /// Cache time-to-live for generated feeds.
    public var ttl: CacheControlDuration

    /// Whether to enable gzip compression on XML responses.
    public var gzipEnabled: Bool

    /// Whether to pretty-print the XML output (tabs + newlines).
    /// `false` produces minified XML for smaller payloads.
    public var prettyPrint: Bool

    /// Value for the `X-Generator` response header. Set to `nil` to omit.
    public var generatorHeader: String?

    /// Content-Type for RSS feed responses.
    /// Defaults to `application/rss+xml; charset=utf-8`.
    public var contentType: HTTPMediaType

    /// Creates a new feed configuration.
    ///
    /// - Parameters:
    ///   - ttl: Cache time-to-live. Defaults to 5 minutes.
    ///   - gzipEnabled: Whether to enable gzip compression. Defaults to `false`.
    ///   - prettyPrint: Whether to pretty-print XML output. Defaults to `false`.
    ///   - generatorHeader: Value for the `X-Generator` header. Defaults to `"PodcastFeedMaker"`.
    ///   - contentType: Content-Type for feed responses. Defaults to `application/rss+xml; charset=utf-8`.
    public init(
        ttl: CacheControlDuration = .minutes(5),
        gzipEnabled: Bool = false,
        prettyPrint: Bool = false,
        generatorHeader: String? = "PodcastFeedMaker",
        contentType: HTTPMediaType = HTTPMediaType(type: "application", subType: "rss+xml", parameters: ["charset": "utf-8"])
    ) {
        self.ttl = ttl
        self.gzipEnabled = gzipEnabled
        self.prettyPrint = prettyPrint
        self.generatorHeader = generatorHeader
        self.contentType = contentType
    }
}

/// Represents a Cache-Control duration.
public enum CacheControlDuration: Sendable, Equatable {
    /// A duration in seconds.
    case seconds(Int)
    /// A duration in minutes.
    case minutes(Int)
    /// A duration in hours.
    case hours(Int)

    /// The total number of seconds.
    public var totalSeconds: Int {
        switch self {
        case .seconds(let value): value
        case .minutes(let value): value * 60
        case .hours(let value): value * 3600
        }
    }
}

extension Application {
    /// The podcast feed configuration for this application.
    public var feedConfiguration: FeedConfiguration {
        get { self.storage[FeedConfigurationKey.self] ?? FeedConfiguration() }
        set { self.storage[FeedConfigurationKey.self] = newValue }
    }

    private struct FeedConfigurationKey: StorageKey {
        typealias Value = FeedConfiguration
    }
}
