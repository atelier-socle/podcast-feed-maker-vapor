import Vapor

/// Configuration for feed metrics collection.
///
/// Controls the metric name prefix and which metrics are emitted.
///
/// ```swift
/// app.feedMetricsConfiguration = FeedMetricsConfiguration(
///     prefix: "myapp",
///     enableResponseSizeRecording: true
/// )
/// ```
public struct FeedMetricsConfiguration: Sendable {

    /// Metric name prefix. Defaults to `"pfv"`.
    public var prefix: String

    /// Whether to record response body size. Defaults to `true`.
    /// Disable if response bodies are very large and measuring size is expensive.
    public var enableResponseSizeRecording: Bool

    /// Creates a new metrics configuration.
    ///
    /// - Parameters:
    ///   - prefix: Metric name prefix. Defaults to `"pfv"`.
    ///   - enableResponseSizeRecording: Whether to record response size. Defaults to `true`.
    public init(
        prefix: String = "pfv",
        enableResponseSizeRecording: Bool = true
    ) {
        self.prefix = prefix
        self.enableResponseSizeRecording = enableResponseSizeRecording
    }
}

extension Application {
    /// The feed metrics configuration for this application.
    public var feedMetricsConfiguration: FeedMetricsConfiguration {
        get { self.storage[FeedMetricsConfigurationKey.self] ?? FeedMetricsConfiguration() }
        set { self.storage[FeedMetricsConfigurationKey.self] = newValue }
    }

    private struct FeedMetricsConfigurationKey: StorageKey {
        typealias Value = FeedMetricsConfiguration
    }
}
