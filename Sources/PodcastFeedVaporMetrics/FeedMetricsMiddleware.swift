import Metrics
import PodcastFeedVapor
import Vapor

/// Vapor middleware that records feed serving metrics via the swift-metrics API.
///
/// Emits counters, timers, and recorders for every feed request. Compatible with
/// any swift-metrics backend (Prometheus, StatsD, Datadog, etc.).
///
/// ```swift
/// import PodcastFeedVaporMetrics
///
/// // Register globally
/// app.middleware.use(FeedMetricsMiddleware())
///
/// // Or on specific route groups
/// app.grouped(FeedMetricsMiddleware()).podcastFeed("feed.xml") { req in
///     try await loadFeed(on: req.db)
/// }
/// ```
///
/// Metrics emitted (all prefixed with `pfv_`):
/// - `pfv_feed_requests_total` — Counter with dimensions: route, status, cache (hit/miss/none)
/// - `pfv_feed_request_duration_seconds` — Timer with dimensions: route, status
/// - `pfv_feed_response_size_bytes` — Recorder with dimensions: route
public struct FeedMetricsMiddleware: AsyncMiddleware, Sendable {

    /// The metric name prefix. Defaults to `"pfv"`.
    private let prefix: String

    /// Creates a new feed metrics middleware.
    ///
    /// - Parameter prefix: Metric name prefix. Defaults to `"pfv"`.
    public init(prefix: String = "pfv") {
        self.prefix = prefix
    }

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let start = DispatchTime.now()
        let route = request.url.path

        let response: Response
        do {
            response = try await next.respond(to: request)
        } catch {
            // Record error metrics
            let duration = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
            Counter(
                label: "\(prefix)_feed_requests_total",
                dimensions: [("route", route), ("status", "500"), ("cache", "none")]
            ).increment()
            Timer(
                label: "\(prefix)_feed_request_duration_seconds",
                dimensions: [("route", route), ("status", "500")]
            ).recordNanoseconds(duration)
            throw error
        }

        let duration = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        let status = String(response.status.code)

        // Determine cache status from response characteristics
        let cacheStatus = determineCacheStatus(response: response)

        Counter(
            label: "\(prefix)_feed_requests_total",
            dimensions: [("route", route), ("status", status), ("cache", cacheStatus)]
        ).increment()

        Timer(
            label: "\(prefix)_feed_request_duration_seconds",
            dimensions: [("route", route), ("status", status)]
        ).recordNanoseconds(duration)

        // Record response size for successful responses with a body
        if let bodyData = response.body.data {
            Recorder(
                label: "\(prefix)_feed_response_size_bytes",
                dimensions: [("route", route)]
            ).record(bodyData.count)
        }

        return response
    }

    /// Determines cache status from response characteristics.
    ///
    /// - 304 Not Modified → "hit"
    /// - Has ETag header → "hit" (served from `StreamingCacheResponse` cache)
    /// - No ETag → "miss" for RSS/XML responses, "none" for non-feed responses
    private func determineCacheStatus(response: Response) -> String {
        if response.status == .notModified {
            return "hit"
        }

        guard let contentType = response.headers.contentType,
            contentType.subType.contains("rss") || contentType.subType.contains("xml")
        else {
            return "none"
        }

        if response.headers.first(name: .eTag) != nil {
            return "hit"
        }

        return "miss"
    }
}
