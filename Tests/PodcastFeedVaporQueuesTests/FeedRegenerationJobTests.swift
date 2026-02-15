import Foundation
import Queues
import Testing
import VaporTesting

@testable import PodcastFeedVapor
@testable import PodcastFeedVaporQueues

// MARK: - Payload Tests

@Suite("FeedRegenerationPayload Tests")
struct FeedRegenerationPayloadTests {

    @Test("Payload encodes to JSON with correct keys")
    func encodesToJSON() throws {
        let payload = FeedRegenerationPayload(feedIdentifier: "show-123", reason: "episode_added")
        let data = try JSONEncoder().encode(payload)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("feedIdentifier"))
        #expect(json.contains("show-123"))
        #expect(json.contains("reason"))
        #expect(json.contains("episode_added"))
    }

    @Test("Payload decodes from JSON")
    func decodesFromJSON() throws {
        let json = """
            {"feedIdentifier":"show-456","reason":"metadata_updated"}
            """
        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(FeedRegenerationPayload.self, from: data)
        #expect(payload.feedIdentifier == "show-456")
        #expect(payload.reason == "metadata_updated")
    }

    @Test("Payload with nil reason encodes and decodes")
    func nilReason() throws {
        let payload = FeedRegenerationPayload(feedIdentifier: "show-789")
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(FeedRegenerationPayload.self, from: data)
        #expect(decoded.feedIdentifier == "show-789")
        #expect(decoded.reason == nil)
    }

    @Test("Payload roundtrip encoding preserves values")
    func roundtrip() throws {
        let original = FeedRegenerationPayload(feedIdentifier: "feed-abc", reason: "new_episode")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FeedRegenerationPayload.self, from: data)
        #expect(decoded.feedIdentifier == original.feedIdentifier)
        #expect(decoded.reason == original.reason)
    }

    @Test("Payload with empty feedIdentifier")
    func emptyIdentifier() throws {
        let payload = FeedRegenerationPayload(feedIdentifier: "")
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(FeedRegenerationPayload.self, from: data)
        #expect(decoded.feedIdentifier == "")
        #expect(decoded.reason == nil)
    }
}

// MARK: - Spy Handler

/// Spy handler that records calls to `regenerate`.
private actor SpyFeedRegenerator: FeedRegenerationHandler {
    var calls: [(feedIdentifier: String, reason: String?)] = []

    func regenerate(feedIdentifier: String, reason: String?, context: QueueContext) async throws {
        calls.append((feedIdentifier, reason))
    }
}

/// Handler that always throws for testing the error path.
private struct FailingRegenerator: FeedRegenerationHandler {
    struct RegenerationFailed: Error {}

    func regenerate(feedIdentifier: String, reason: String?, context: QueueContext) async throws {
        throw RegenerationFailed()
    }
}

// MARK: - Handler Protocol Tests

@Suite("FeedRegenerationHandler Protocol Tests")
struct FeedRegenerationHandlerTests {

    @Test("FeedRegenerationHandler protocol conformance compiles")
    func protocolConformance() {
        let handler: any FeedRegenerationHandler = SpyFeedRegenerator()
        _ = handler
    }
}

// MARK: - Job Construction Tests

@Suite("FeedRegenerationJob Tests")
struct FeedRegenerationJobTests {

    @Test("Job initializes with handler")
    func initWithHandler() {
        let job = FeedRegenerationJob(handler: SpyFeedRegenerator())
        _ = job
    }

    @Test("Job Payload type is FeedRegenerationPayload")
    func payloadTypeAlias() {
        let isCorrectType = FeedRegenerationJob.Payload.self == FeedRegenerationPayload.self
        #expect(isCorrectType)
    }

    @Test("Job conforms to AsyncJob")
    func asyncJobConformance() {
        let job = FeedRegenerationJob(handler: SpyFeedRegenerator())
        let asyncJob: any AsyncJob = job
        _ = asyncJob
    }

    @Test("Application extension registers job without error")
    func registerJob() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                app.registerFeedRegenerationJob(handler: SpyFeedRegenerator())
            }
        )
    }

    @Test("Dequeue calls handler.regenerate with correct parameters")
    func dequeueCallsHandler() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let spy = SpyFeedRegenerator()
                let job = FeedRegenerationJob(handler: spy)
                let payload = FeedRegenerationPayload(
                    feedIdentifier: "show-123",
                    reason: "episode_added"
                )
                let context = QueueContext(
                    queueName: .default,
                    configuration: QueuesConfiguration(),
                    application: app,
                    logger: app.logger,
                    on: app.eventLoopGroup.any()
                )
                try await job.dequeue(context, payload)
                let calls = await spy.calls
                #expect(calls.count == 1)
                #expect(calls[0].feedIdentifier == "show-123")
                #expect(calls[0].reason == "episode_added")
            }
        )
    }

    @Test("Dequeue calls handler with nil reason")
    func dequeueWithNilReason() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let spy = SpyFeedRegenerator()
                let job = FeedRegenerationJob(handler: spy)
                let payload = FeedRegenerationPayload(feedIdentifier: "feed-xyz")
                let context = QueueContext(
                    queueName: .default,
                    configuration: QueuesConfiguration(),
                    application: app,
                    logger: app.logger,
                    on: app.eventLoopGroup.any()
                )
                try await job.dequeue(context, payload)
                let calls = await spy.calls
                #expect(calls.count == 1)
                #expect(calls[0].feedIdentifier == "feed-xyz")
                #expect(calls[0].reason == nil)
            }
        )
    }

    @Test("Error handler logs without throwing")
    func errorHandler() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let job = FeedRegenerationJob(handler: SpyFeedRegenerator())
                let payload = FeedRegenerationPayload(
                    feedIdentifier: "show-fail",
                    reason: "test"
                )
                let context = QueueContext(
                    queueName: .default,
                    configuration: QueuesConfiguration(),
                    application: app,
                    logger: app.logger,
                    on: app.eventLoopGroup.any()
                )
                let testError = FailingRegenerator.RegenerationFailed()
                try await job.error(context, testError, payload)
            }
        )
    }
}
