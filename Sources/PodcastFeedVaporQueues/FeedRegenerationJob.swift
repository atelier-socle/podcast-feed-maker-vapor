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

import PodcastFeedVapor
import Queues
import Vapor

/// Payload for a feed regeneration job.
///
/// Contains the identifier of the feed to regenerate and an optional reason.
public struct FeedRegenerationPayload: Codable, Sendable {
    /// Unique identifier for the feed to regenerate (e.g., show ID, slug, or URL).
    public let feedIdentifier: String

    /// Optional reason for regeneration (e.g., "episode_added", "metadata_updated").
    public let reason: String?

    /// Creates a new feed regeneration payload.
    ///
    /// - Parameters:
    ///   - feedIdentifier: Unique identifier for the feed.
    ///   - reason: Optional reason for regeneration.
    public init(feedIdentifier: String, reason: String? = nil) {
        self.feedIdentifier = feedIdentifier
        self.reason = reason
    }
}

/// Handler protocol for feed regeneration logic.
///
/// Implement this protocol in your application to provide the actual
/// feed regeneration logic. The job will call your handler when dequeued.
///
/// ```swift
/// struct MyFeedRegenerator: FeedRegenerationHandler {
///     func regenerate(
///         feedIdentifier: String,
///         reason: String?,
///         context: QueueContext
///     ) async throws {
///         let show = try await Show.find(feedIdentifier, on: context.application.db)
///         let xml = try FeedGenerator().generate(show.toPodcastFeed())
///         try await cache.set(identifier: feedIdentifier, xml: xml, ttl: 600)
///     }
/// }
/// ```
public protocol FeedRegenerationHandler: Sendable {
    /// Regenerate the feed for the given identifier.
    ///
    /// - Parameters:
    ///   - feedIdentifier: The feed to regenerate.
    ///   - reason: Optional reason for regeneration.
    ///   - context: The queue context (provides application, logger, etc.).
    func regenerate(
        feedIdentifier: String,
        reason: String?,
        context: QueueContext
    ) async throws
}

/// Background job for regenerating podcast feed XML.
///
/// Uses Vapor Queues to process feed regeneration in the background.
/// The actual regeneration logic is provided by a ``FeedRegenerationHandler``.
///
/// ```swift
/// import PodcastFeedVaporQueues
/// import QueuesRedisDriver
///
/// // In configure.swift
/// try app.queues.use(.redis(url: "redis://127.0.0.1:6379"))
///
/// let regenerator = MyFeedRegenerator()
/// app.queues.add(FeedRegenerationJob(handler: regenerator))
///
/// // Dispatch a job when content changes
/// try await req.queue.dispatch(
///     FeedRegenerationJob.self,
///     FeedRegenerationPayload(feedIdentifier: "show-123", reason: "episode_added")
/// )
/// ```
public struct FeedRegenerationJob: AsyncJob, Sendable {
    /// The payload type for this job.
    public typealias Payload = FeedRegenerationPayload

    private let handler: any FeedRegenerationHandler

    /// Creates a new feed regeneration job.
    ///
    /// - Parameter handler: The handler providing the regeneration logic.
    public init(handler: any FeedRegenerationHandler) {
        self.handler = handler
    }

    /// Called when the job is dequeued for processing.
    ///
    /// - Parameters:
    ///   - context: The queue context.
    ///   - payload: The feed regeneration payload.
    public func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        context.logger.info(
            "Regenerating feed",
            metadata: [
                "feedIdentifier": .string(payload.feedIdentifier),
                "reason": .string(payload.reason ?? "unspecified")
            ]
        )
        try await handler.regenerate(
            feedIdentifier: payload.feedIdentifier,
            reason: payload.reason,
            context: context
        )
        context.logger.info(
            "Feed regenerated successfully",
            metadata: ["feedIdentifier": .string(payload.feedIdentifier)]
        )
    }

    /// Called when the job fails with an error.
    ///
    /// - Parameters:
    ///   - context: The queue context.
    ///   - error: The error that occurred.
    ///   - payload: The feed regeneration payload.
    public func error(_ context: QueueContext, _ error: any Error, _ payload: Payload) async throws {
        context.logger.error(
            "Feed regeneration failed",
            metadata: [
                "feedIdentifier": .string(payload.feedIdentifier),
                "reason": .string(payload.reason ?? "unspecified"),
                "error": .string(String(describing: error))
            ]
        )
    }
}

// MARK: - Application Extension

extension Application {
    /// Register the feed regeneration job with a custom handler.
    ///
    /// ```swift
    /// app.registerFeedRegenerationJob(handler: MyFeedRegenerator())
    /// ```
    public func registerFeedRegenerationJob(handler: any FeedRegenerationHandler) {
        queues.add(FeedRegenerationJob(handler: handler))
    }
}
