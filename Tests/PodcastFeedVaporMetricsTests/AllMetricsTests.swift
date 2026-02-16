import Testing

/// Parent suite ensuring all metrics tests run sequentially.
///
/// `MetricsSystem.bootstrapInternal` overwrites the global metrics factory,
/// so tests across suites must not run in parallel.
@Suite("PodcastFeedVaporMetrics", .serialized)
enum AllMetricsTests {}
