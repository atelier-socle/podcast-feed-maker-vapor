import MetricsTestKit
import Testing
import VaporTesting

@testable import CoreMetrics
@testable import PodcastFeedVapor
@testable import PodcastFeedVaporMetrics

extension AllMetricsTests {

    @Suite("FeedMetricsMiddleware — Edge Cases")
    struct FeedMetricsMiddlewareEdgeCases {

        @Test("Error response — counter incremented with status 500")
        func errorResponseRecordsMetrics() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            struct TestError: Error {}

            try await withApp(
                configure: { app in
                    app.middleware.use(FeedMetricsMiddleware())
                    app.get(
                        "fail",
                        use: { _ -> Response in
                            throw TestError()
                        })
                },
                { app in
                    try await app.testing().test(
                        .GET, "fail",
                        afterResponse: { res in
                            #expect(res.status == .internalServerError)
                        }
                    )

                    let counters = metrics.counters.filter { $0.label == "pfv_feed_requests_total" }
                    #expect(!counters.isEmpty)
                }
            )
        }

        @Test("Empty response body — size recorder not called")
        func emptyBodyNoSizeRecorded() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            try await withApp(
                configure: { app in
                    app.middleware.use(FeedMetricsMiddleware())
                    app.get(
                        "empty",
                        use: { _ -> Response in
                            Response(status: .noContent)
                        })
                },
                { app in
                    try await app.testing().test(
                        .GET, "empty",
                        afterResponse: { res in
                            #expect(res.status == .noContent)
                        }
                    )

                    // Counter and timer should exist
                    let counters = metrics.counters.filter { $0.label == "pfv_feed_requests_total" }
                    #expect(!counters.isEmpty)

                    // Size recorder should not have values (no body data)
                    let recorders = metrics.recorders.filter { $0.label == "pfv_feed_response_size_bytes" }
                    #expect(recorders.isEmpty)
                }
            )
        }

        @Test("Multiple requests — counter incremented correctly")
        func multipleRequestsCounterAccumulates() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let feed = try makeTestFeed()

            try await withApp(
                configure: { app in
                    app.middleware.use(FeedMetricsMiddleware())
                    app.podcastFeed("feed.xml") { _ in feed }
                },
                { app in
                    for _ in 0..<3 {
                        try await app.testing().test(
                            .GET, "feed.xml",
                            afterResponse: { res in
                                #expect(res.status == .ok)
                            }
                        )
                    }

                    // At least 3 counter increments recorded
                    let counters = metrics.counters.filter { $0.label == "pfv_feed_requests_total" }
                    let totalValue = counters.reduce(Int64(0)) { $0 + $1.totalValue }
                    #expect(totalValue >= 3)
                }
            )
        }

        @Test("Route path extraction — various URL patterns")
        func routePathExtraction() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let feed = try makeTestFeed()

            try await withApp(
                configure: { app in
                    app.middleware.use(FeedMetricsMiddleware())
                    app.podcastFeed("shows", "123", "feed.xml") { _ in feed }
                },
                { app in
                    try await app.testing().test(
                        .GET, "shows/123/feed.xml",
                        afterResponse: { res in
                            #expect(res.status == .ok)
                        }
                    )

                    let counters = metrics.counters.filter { $0.label == "pfv_feed_requests_total" }
                    #expect(!counters.isEmpty)
                    let routeDim = counters.first?.dimensions.first { $0.0 == "route" }
                    #expect(routeDim?.1 == "/shows/123/feed.xml")
                }
            )
        }

        @Test("Status dimension — records correct HTTP status code")
        func statusDimensionCorrect() async throws {
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
                    let statusDim = counters.first?.dimensions.first { $0.0 == "status" }
                    #expect(statusDim?.1 == "200")
                }
            )
        }

        @Test("Cache miss detection — RSS without ETag reports miss")
        func cacheMissDetection() async throws {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let feed = try makeTestFeed()

            try await withApp(
                configure: { app in
                    app.middleware.use(FeedMetricsMiddleware())
                    // No FeedCacheMiddleware — so no ETag
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
                    let cacheDim = counters.first?.dimensions.first { $0.0 == "cache" }
                    #expect(cacheDim?.1 == "miss")
                }
            )
        }
    }
}
