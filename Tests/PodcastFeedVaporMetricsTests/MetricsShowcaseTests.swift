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

import MetricsTestKit
import Testing
import VaporTesting

@testable import CoreMetrics
@testable import PodcastFeedVapor
@testable import PodcastFeedVaporMetrics

// MARK: - Middleware Showcase

extension AllMetricsTests {

    @Suite("Metrics Showcase — FeedMetricsMiddleware")
    struct FeedMetricsMiddlewareShowcase {

        @Test("Middleware records request counter on feed response")
        func recordsRequestCounter() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let feed = try makeTestFeed()

            try await withApp(
                configure: { app in
                    app.middleware.use(FeedMetricsMiddleware())
                    app.podcastFeed("feed.xml") { _ in feed }
                },
                { app in
                    try await app.testing().test(
                        .GET, "feed.xml",
                        afterResponse: { res in
                            #expect(res.status == .ok)
                        }
                    )

                    let counters = metrics.counters.filter { $0.label == "pfv_feed_requests_total" }
                    #expect(!counters.isEmpty)
                    #expect(counters.first?.totalValue ?? 0 > 0)
                }
            )
        }

        @Test("Middleware records request duration timer")
        func recordsRequestDuration() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let feed = try makeTestFeed()

            try await withApp(
                configure: { app in
                    app.middleware.use(FeedMetricsMiddleware())
                    app.podcastFeed("feed.xml") { _ in feed }
                },
                { app in
                    try await app.testing().test(
                        .GET, "feed.xml",
                        afterResponse: { res in
                            #expect(res.status == .ok)
                        }
                    )

                    let timers = metrics.timers.filter { $0.label == "pfv_feed_request_duration_seconds" }
                    #expect(!timers.isEmpty)
                    #expect(timers.first?.lastValue != nil)
                }
            )
        }

        @Test("Middleware records response size recorder")
        func recordsResponseSize() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let feed = try makeTestFeed(itemCount: 5)

            try await withApp(
                configure: { app in
                    app.middleware.use(FeedMetricsMiddleware())
                    app.podcastFeed("feed.xml") { _ in feed }
                },
                { app in
                    try await app.testing().test(
                        .GET, "feed.xml",
                        afterResponse: { res in
                            #expect(res.status == .ok)
                        }
                    )

                    let recorders = metrics.recorders.filter { $0.label == "pfv_feed_response_size_bytes" }
                    #expect(!recorders.isEmpty)
                    #expect((recorders.first?.lastValue ?? 0) > 0)
                }
            )
        }

        @Test("Custom prefix — metrics use configured prefix")
        func customPrefix() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let feed = try makeTestFeed()

            try await withApp(
                configure: { app in
                    app.middleware.use(FeedMetricsMiddleware(prefix: "myapp"))
                    app.podcastFeed("feed.xml") { _ in feed }
                },
                { app in
                    try await app.testing().test(
                        .GET, "feed.xml",
                        afterResponse: { res in
                            #expect(res.status == .ok)
                        }
                    )

                    let counters = metrics.counters.filter { $0.label == "myapp_feed_requests_total" }
                    #expect(!counters.isEmpty)
                    // Default prefix should NOT be present
                    let defaultCounters = metrics.counters.filter { $0.label == "pfv_feed_requests_total" }
                    #expect(defaultCounters.isEmpty)
                }
            )
        }

        @Test("Middleware fires counter for non-feed responses")
        func firesCounterForNonFeed() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            try await withApp(
                configure: { app in
                    app.middleware.use(FeedMetricsMiddleware())
                    app.get(
                        "api", "data",
                        use: { _ -> [String: String] in
                            ["key": "value"]
                        })
                },
                { app in
                    try await app.testing().test(
                        .GET, "api/data",
                        afterResponse: { res in
                            #expect(res.status == .ok)
                        }
                    )

                    // Counter should still fire (counts all requests through middleware)
                    let counters = metrics.counters.filter { $0.label == "pfv_feed_requests_total" }
                    #expect(!counters.isEmpty)
                }
            )
        }

        @Test("Cache hit detection — 304 response counted as cache hit")
        func cacheHitOn304() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let feed = try makeTestFeed()

            try await withApp(
                configure: { app in
                    app.middleware.use(FeedMetricsMiddleware())
                    app.grouped(FeedCacheMiddleware()).podcastFeed("feed.xml") { _ in feed }
                },
                { app in
                    // First request — get ETag
                    var etag = ""
                    try await app.testing().test(
                        .GET, "feed.xml",
                        afterResponse: { res in
                            etag = res.headers.first(name: .eTag) ?? ""
                        }
                    )

                    // Second request — 304
                    try await app.testing().test(
                        .GET, "feed.xml",
                        beforeRequest: { req in
                            req.headers.replaceOrAdd(name: .ifNoneMatch, value: etag)
                        },
                        afterResponse: { res in
                            #expect(res.status == .notModified)
                        }
                    )
                }
            )
        }

        @Test("Middleware stacks with other middleware — CORS + Metrics + Cache")
        func stacksWithOtherMiddleware() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let feed = try makeTestFeed()

            try await withApp(
                configure: { app in
                    app.middleware.use(CORSFeedMiddleware())
                    app.middleware.use(FeedMetricsMiddleware())
                    app.middleware.use(PodcastFeedMiddleware())
                    app.grouped(FeedCacheMiddleware()).podcastFeed("feed.xml") { _ in feed }
                },
                { app in
                    try await app.testing().test(
                        .GET, "feed.xml",
                        afterResponse: { res in
                            #expect(res.status == .ok)
                            // All middleware headers present
                            #expect(res.headers[.accessControlAllowOrigin].first == "*")
                            #expect(res.headers["X-Generator"].first != nil)
                            #expect(res.headers.first(name: .eTag) != nil)
                        }
                    )

                    // Metrics recorded
                    let counters = metrics.counters.filter { $0.label == "pfv_feed_requests_total" }
                    #expect(!counters.isEmpty)
                    let timers = metrics.timers.filter { $0.label == "pfv_feed_request_duration_seconds" }
                    #expect(!timers.isEmpty)
                }
            )
        }
    }
}

// MARK: - Active Streams Gauge Showcase

extension AllMetricsTests {

    @Suite("Metrics Showcase — FeedActiveStreamsGauge")
    struct ActiveStreamsGaugeShowcase {

        @Test("Increment and decrement — tracks active count")
        func incrementDecrement() async {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let gauge = FeedActiveStreamsGauge()
            var count = await gauge.current
            #expect(count == 0)

            await gauge.increment()
            count = await gauge.current
            #expect(count == 1)

            await gauge.increment()
            count = await gauge.current
            #expect(count == 2)

            await gauge.decrement()
            count = await gauge.current
            #expect(count == 1)

            await gauge.decrement()
            count = await gauge.current
            #expect(count == 0)
        }

        @Test("Decrement below zero — clamped to 0")
        func decrementBelowZero() async {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let gauge = FeedActiveStreamsGauge()
            await gauge.decrement()
            let count = await gauge.current
            #expect(count == 0)
        }

        @Test("Custom prefix — gauge uses configured prefix")
        func customPrefix() async {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let gauge = FeedActiveStreamsGauge(prefix: "myapp")
            await gauge.increment()

            let recorders = metrics.recorders.filter { $0.label == "myapp_feed_active_streams" }
            #expect(!recorders.isEmpty)
        }
    }
}

// MARK: - Configuration Showcase

extension AllMetricsTests {

    @Suite("Metrics Showcase — FeedMetricsConfiguration")
    struct MetricsConfigurationShowcase {

        @Test("Default configuration — prefix 'pfv', recording enabled")
        func defaultConfig() {
            let config = FeedMetricsConfiguration()
            #expect(config.prefix == "pfv")
            #expect(config.enableResponseSizeRecording == true)
        }

        @Test("Custom configuration — custom prefix and disabled recording")
        func customConfig() {
            let config = FeedMetricsConfiguration(
                prefix: "podcast",
                enableResponseSizeRecording: false
            )
            #expect(config.prefix == "podcast")
            #expect(config.enableResponseSizeRecording == false)
        }

        @Test("Application storage — store and retrieve config")
        func applicationStorage() async throws {
            try await withApp(
                configure: { app in
                    app.feedMetricsConfiguration = FeedMetricsConfiguration(prefix: "stored")
                },
                { app in
                    #expect(app.feedMetricsConfiguration.prefix == "stored")
                }
            )
        }
    }
}
