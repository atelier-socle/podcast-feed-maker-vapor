import Testing
import VaporTesting
@testable import PodcastFeedVapor

@Suite("Health Check Tests")
struct HealthCheckTests {
    @Test("GET /health returns 200 with ok status")
    func healthEndpoint() async throws {
        try await withApp(
            configure: { app in
                app.healthCheck()
            },
            { app in
                try await app.testing().test(
                    .GET, "health",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("ok"))
                    }
                )
            }
        )
    }

    @Test("Custom health path")
    func customHealthPath() async throws {
        try await withApp(
            configure: { app in
                app.healthCheck(path: "status")
            },
            { app in
                try await app.testing().test(
                    .GET, "status",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                    }
                )
            }
        )
    }
}
