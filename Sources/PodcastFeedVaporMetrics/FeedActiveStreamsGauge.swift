import Metrics

/// Tracks the number of active streaming feed responses.
///
/// Call ``increment()`` when a stream starts and ``decrement()`` when it ends.
/// The current count is emitted as a `pfv_feed_active_streams` gauge.
///
/// ```swift
/// let streams = FeedActiveStreamsGauge()
/// await streams.increment()   // Stream started
/// // ... streaming ...
/// await streams.decrement()   // Stream ended
/// ```
public actor FeedActiveStreamsGauge {
    private var count: Int = 0
    private let gauge: Gauge

    /// Creates a new active streams gauge.
    ///
    /// - Parameter prefix: Metric name prefix. Defaults to `"pfv"`.
    public init(prefix: String = "pfv") {
        self.gauge = Gauge(label: "\(prefix)_feed_active_streams")
    }

    /// Records that a new stream has started.
    public func increment() {
        count += 1
        gauge.record(count)
    }

    /// Records that a stream has ended.
    public func decrement() {
        count = max(0, count - 1)
        gauge.record(count)
    }

    /// The current number of active streams.
    public var current: Int {
        count
    }
}
