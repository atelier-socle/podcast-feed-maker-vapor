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
