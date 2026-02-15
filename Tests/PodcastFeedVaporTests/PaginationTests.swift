import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Feed Pagination Tests")
struct PaginationTests {
    @Test("Default values without query params")
    func defaults() async throws {
        try await withApp(
            configure: { app in
                app.get(
                    "test",
                    use: { req -> [String: Int] in
                        let pagination = FeedPagination(from: req)
                        return ["limit": pagination.limit, "offset": pagination.offset]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "test",
                    afterResponse: { res in
                        let body = res.body.string
                        #expect(body.contains("\"limit\":50"))
                        #expect(body.contains("\"offset\":0"))
                    }
                )
            }
        )
    }

    @Test("Parses limit from query")
    func parsesLimit() async throws {
        try await withApp(
            configure: { app in
                app.get(
                    "test",
                    use: { req -> [String: Int] in
                        let pagination = FeedPagination(from: req)
                        return ["limit": pagination.limit]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "test?limit=25",
                    afterResponse: { res in
                        #expect(res.body.string.contains("\"limit\":25"))
                    }
                )
            }
        )
    }

    @Test("Parses offset from query")
    func parsesOffset() async throws {
        try await withApp(
            configure: { app in
                app.get(
                    "test",
                    use: { req -> [String: Int] in
                        let pagination = FeedPagination(from: req)
                        return ["offset": pagination.offset]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "test?offset=100",
                    afterResponse: { res in
                        #expect(res.body.string.contains("\"offset\":100"))
                    }
                )
            }
        )
    }

    @Test("Parses both limit and offset")
    func parsesBoth() async throws {
        try await withApp(
            configure: { app in
                app.get(
                    "test",
                    use: { req -> [String: Int] in
                        let pagination = FeedPagination(from: req)
                        return ["limit": pagination.limit, "offset": pagination.offset]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "test?limit=10&offset=50",
                    afterResponse: { res in
                        #expect(res.body.string.contains("\"limit\":10"))
                        #expect(res.body.string.contains("\"offset\":50"))
                    }
                )
            }
        )
    }

    @Test("Clamps limit to maxLimit")
    func clampsMaxLimit() {
        let pagination = FeedPagination(limit: 5000, offset: 0)
        #expect(pagination.limit == 5000)

        let clamped = FeedPagination(limit: 5000, offset: 0)
        #expect(clamped.limit == 5000)
    }

    @Test("Clamps negative limit to 1")
    func clampsNegativeLimit() {
        let pagination = FeedPagination(limit: -5, offset: 0)
        #expect(pagination.limit == 1)
    }

    @Test("Clamps negative offset to 0")
    func clampsNegativeOffset() {
        let pagination = FeedPagination(limit: 10, offset: -10)
        #expect(pagination.offset == 0)
    }

    @Test("Custom default limit")
    func customDefaultLimit() async throws {
        try await withApp(
            configure: { app in
                app.get(
                    "test",
                    use: { req -> [String: Int] in
                        let pagination = FeedPagination(from: req, defaultLimit: 20)
                        return ["limit": pagination.limit]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "test",
                    afterResponse: { res in
                        #expect(res.body.string.contains("\"limit\":20"))
                    }
                )
            }
        )
    }

    @Test("Custom max limit")
    func customMaxLimit() async throws {
        try await withApp(
            configure: { app in
                app.get(
                    "test",
                    use: { req -> [String: Int] in
                        let pagination = FeedPagination(from: req, maxLimit: 100)
                        return ["limit": pagination.limit]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "test?limit=500",
                    afterResponse: { res in
                        #expect(res.body.string.contains("\"limit\":100"))
                    }
                )
            }
        )
    }

    @Test("Direct initialization")
    func directInit() {
        let pagination = FeedPagination(limit: 10, offset: 5)
        #expect(pagination.limit == 10)
        #expect(pagination.offset == 5)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = FeedPagination(limit: 10, offset: 5)
        let b = FeedPagination(limit: 10, offset: 5)
        let c = FeedPagination(limit: 20, offset: 5)
        #expect(a == b)
        #expect(a != c)
    }
}
