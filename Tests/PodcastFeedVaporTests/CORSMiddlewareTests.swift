import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("CORS Feed Middleware Tests")
struct CORSMiddlewareTests {
    @Test("Adds CORS headers with wildcard origin by default")
    func wildcardOrigin() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware()).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowOrigin].first == "*")
                    }
                )
            }
        )
    }

    @Test("Handles preflight OPTIONS request")
    func preflightOptions() async throws {
        try await withApp(
            configure: { app in
                app.middleware.use(CORSFeedMiddleware())
                app.get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .OPTIONS, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .noContent)
                        #expect(res.headers[.accessControlAllowOrigin].first == "*")
                    }
                )
            }
        )
    }

    @Test("Allows specific origins")
    func specificOrigin() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware(allowedOrigins: ["https://myapp.com"])).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    beforeRequest: { req in
                        req.headers.replaceOrAdd(name: .origin, value: "https://myapp.com")
                    },
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowOrigin].first == "https://myapp.com")
                    }
                )
            }
        )
    }

    @Test("Rejects non-allowed origins")
    func rejectsNonAllowedOrigin() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware(allowedOrigins: ["https://myapp.com"])).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    beforeRequest: { req in
                        req.headers.replaceOrAdd(name: .origin, value: "https://evil.com")
                    },
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowOrigin].isEmpty)
                    }
                )
            }
        )
    }

    @Test("Includes allowed methods")
    func allowedMethods() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware()).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let methods = res.headers[.accessControlAllowMethods].first ?? ""
                        #expect(methods.contains("GET"))
                        #expect(methods.contains("HEAD"))
                        #expect(methods.contains("OPTIONS"))
                    }
                )
            }
        )
    }

    @Test("Includes allowed headers")
    func allowedHeaders() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware()).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let headers = res.headers[.accessControlAllowHeaders].first ?? ""
                        #expect(headers.contains("If-None-Match"))
                        #expect(headers.contains("If-Modified-Since"))
                    }
                )
            }
        )
    }

    @Test("Max-Age header present")
    func maxAgeHeader() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware()).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.accessControlMaxAge].first == "86400")
                    }
                )
            }
        )
    }

    @Test("Credentials header when enabled")
    func credentialsEnabled() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware(allowCredentials: true)).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowCredentials].first == "true")
                    }
                )
            }
        )
    }

    @Test("No credentials header when disabled")
    func credentialsDisabled() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware()).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowCredentials].isEmpty)
                    }
                )
            }
        )
    }
}
