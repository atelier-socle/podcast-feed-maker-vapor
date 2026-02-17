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
