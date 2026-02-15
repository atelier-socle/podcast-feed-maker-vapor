import Testing
import VaporTesting

@testable import PodcastFeedVapor

// MARK: - Mock Client

/// A mock HTTP client for testing PodpingNotifier without real network calls.
private struct MockPodpingClient: Client, @unchecked Sendable {
    let eventLoop: EventLoop
    private let responseStatus: HTTPStatus

    init(eventLoop: EventLoop, status: HTTPStatus) {
        self.eventLoop = eventLoop
        self.responseStatus = status
    }

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        eventLoop.makeSucceededFuture(ClientResponse(status: responseStatus))
    }

    func delegating(to eventLoop: EventLoop) -> Client {
        MockPodpingClient(eventLoop: eventLoop, status: responseStatus)
    }
}

// MARK: - PodpingNotifier.notify() Coverage

@Suite("Coverage — PodpingNotifier.notify()")
struct PodpingNotifyCoverage {

    @Test("Notify success — 200 response completes without error")
    func notifySuccess() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let client = MockPodpingClient(eventLoop: app.eventLoopGroup.any(), status: .ok)
                let notifier = PodpingNotifier(client: client, endpoint: "https://mock.podping.local")
                try await notifier.notify(feedURL: "https://example.com/feed.xml")
            }
        )
    }

    @Test("Notify with auth — exercises Bearer token path")
    func notifyWithAuth() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let client = MockPodpingClient(eventLoop: app.eventLoopGroup.any(), status: .ok)
                let notifier = PodpingNotifier(
                    client: client,
                    endpoint: "https://mock.podping.local",
                    authToken: "test-secret"
                )
                try await notifier.notify(
                    feedURL: "https://example.com/feed.xml",
                    reason: .live,
                    medium: .music
                )
            }
        )
    }

    @Test("Notify server error — throws PodpingError.serverError(500)")
    func notifyServerError() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let client = MockPodpingClient(
                    eventLoop: app.eventLoopGroup.any(),
                    status: .internalServerError
                )
                let notifier = PodpingNotifier(client: client, endpoint: "https://mock.podping.local")
                await #expect(throws: PodpingError.serverError(500)) {
                    try await notifier.notify(feedURL: "https://example.com/feed.xml")
                }
            }
        )
    }
}

// MARK: - BatchAudit Success Path Coverage

@Suite("Coverage — Batch Audit Success Path")
struct BatchAuditSuccessCoverage {

    @Test("Successful audit — valid RSS produces score and grade")
    func auditValidFeed() async throws {
        let validRSS = """
            <?xml version="1.0" encoding="UTF-8"?>
            <rss version="2.0">
                <channel>
                    <title>Test Podcast</title>
                    <link>https://example.com</link>
                    <description>A test podcast feed</description>
                    <item>
                        <title>Episode 1</title>
                        <enclosure url="https://example.com/ep1.mp3" length="1000000" type="audio/mpeg"/>
                    </item>
                </channel>
            </rss>
            """

        try await withApp(
            configure: { app in
                app.get("valid-feed.xml") { _ -> Response in
                    Response.xml(validRSS)
                }
                app.batchAudit("audit")
            },
            { app in
                try await app.testing(method: .running(port: 18754)).test(
                    .GET, "audit?urls=http://localhost:18754/valid-feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        let body = res.body.string
                        #expect(body.contains("\"score\""))
                        #expect(body.contains("\"grade\""))
                    }
                )
            }
        )
    }
}
