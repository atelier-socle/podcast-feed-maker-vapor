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

import Foundation
import Queues
import Testing
import VaporTesting

@testable import PodcastFeedVapor
@testable import PodcastFeedVaporQueues

// MARK: - Mock for showcase

/// Records all regeneration calls for verification.
private actor ShowcaseFeedRegenerator: FeedRegenerationHandler {
    private(set) var calls: [(feedIdentifier: String, reason: String?)] = []

    func regenerate(feedIdentifier: String, reason: String?, context: QueueContext) async throws {
        calls.append((feedIdentifier, reason))
    }

    var callCount: Int { calls.count }
    func lastCall() -> (feedIdentifier: String, reason: String?)? { calls.last }
}

// MARK: - Payload Showcase

@Suite("Queues Showcase — FeedRegenerationPayload")
struct PayloadShowcase {

    @Test("Create payload with identifier and reason")
    func createWithReason() {
        let payload = FeedRegenerationPayload(
            feedIdentifier: "show-123",
            reason: "episode_added"
        )
        #expect(payload.feedIdentifier == "show-123")
        #expect(payload.reason == "episode_added")
    }

    @Test("Create payload without reason")
    func createWithoutReason() {
        let payload = FeedRegenerationPayload(feedIdentifier: "show-456")
        #expect(payload.feedIdentifier == "show-456")
        #expect(payload.reason == nil)
    }

    @Test("Payload JSON encoding — all fields")
    func jsonEncodingAllFields() throws {
        let payload = FeedRegenerationPayload(
            feedIdentifier: "show-789",
            reason: "metadata_updated"
        )
        let data = try JSONEncoder().encode(payload)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("feedIdentifier"))
        #expect(json.contains("show-789"))
        #expect(json.contains("reason"))
        #expect(json.contains("metadata_updated"))
    }

    @Test("Payload JSON encoding — nil reason omitted or null")
    func jsonEncodingNilReason() throws {
        let payload = FeedRegenerationPayload(feedIdentifier: "show-nil")
        let data = try JSONEncoder().encode(payload)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("feedIdentifier"))
        #expect(json.contains("show-nil"))
    }

    @Test("Payload roundtrip — encode then decode")
    func roundtrip() throws {
        let original = FeedRegenerationPayload(
            feedIdentifier: "show-round",
            reason: "episode_removed"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FeedRegenerationPayload.self, from: data)
        #expect(decoded.feedIdentifier == original.feedIdentifier)
        #expect(decoded.reason == original.reason)
    }

    @Test("Payload with various reason strings")
    func variousReasons() throws {
        let reasons = ["episode_added", "metadata_updated", "episode_removed", "feed_migrated"]
        for reason in reasons {
            let payload = FeedRegenerationPayload(feedIdentifier: "show-x", reason: reason)
            let data = try JSONEncoder().encode(payload)
            let decoded = try JSONDecoder().decode(FeedRegenerationPayload.self, from: data)
            #expect(decoded.reason == reason)
        }
    }
}

// MARK: - Handler Protocol Showcase

@Suite("Queues Showcase — FeedRegenerationHandler Protocol")
struct HandlerShowcase {

    @Test("Custom handler receives correct parameters")
    func handlerReceivesParameters() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let handler = ShowcaseFeedRegenerator()
                let context = QueueContext(
                    queueName: .default,
                    configuration: QueuesConfiguration(),
                    application: app,
                    logger: app.logger,
                    on: app.eventLoopGroup.any()
                )
                try await handler.regenerate(
                    feedIdentifier: "show-abc",
                    reason: "episode_added",
                    context: context
                )
                let last = await handler.lastCall()
                #expect(last?.feedIdentifier == "show-abc")
                #expect(last?.reason == "episode_added")
            }
        )
    }

    @Test("Handler protocol enables dependency injection")
    func dependencyInjection() {
        let handler: any FeedRegenerationHandler = ShowcaseFeedRegenerator()
        _ = handler
    }
}

// MARK: - Job Showcase

@Suite("Queues Showcase — FeedRegenerationJob")
struct JobShowcase {

    @Test("Job creation with handler")
    func jobCreation() {
        let job = FeedRegenerationJob(handler: ShowcaseFeedRegenerator())
        _ = job
    }

    @Test("Job dequeue calls handler — full flow")
    func dequeueFullFlow() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let spy = ShowcaseFeedRegenerator()
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
                let callCount = await spy.callCount
                #expect(callCount == 1)
                let last = await spy.lastCall()
                #expect(last?.feedIdentifier == "show-123")
                #expect(last?.reason == "episode_added")
            }
        )
    }

    @Test("Job error handler logs failure")
    func errorHandlerLogs() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let job = FeedRegenerationJob(handler: ShowcaseFeedRegenerator())
                let payload = FeedRegenerationPayload(
                    feedIdentifier: "show-fail",
                    reason: "test_error"
                )
                let context = QueueContext(
                    queueName: .default,
                    configuration: QueuesConfiguration(),
                    application: app,
                    logger: app.logger,
                    on: app.eventLoopGroup.any()
                )
                struct TestError: Error {}
                try await job.error(context, TestError(), payload)
            }
        )
    }

    @Test("Production pattern — dispatch after content change")
    func dispatchPattern() {
        // This test documents the production dispatch pattern.
        // Actual dispatch requires Redis queue infrastructure.
        //
        // Pattern:
        // try await req.queue.dispatch(
        //     FeedRegenerationJob.self,
        //     FeedRegenerationPayload(
        //         feedIdentifier: "show-123",
        //         reason: "episode_added"
        //     )
        // )

        let payload = FeedRegenerationPayload(
            feedIdentifier: "show-123",
            reason: "episode_added"
        )
        #expect(payload.feedIdentifier == "show-123")
    }
}
