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

import PodcastFeedMaker
import Vapor

/// Creates a streaming HTTP response from a `PodcastFeed` using
/// PodcastFeedMaker's `StreamingFeedGenerator`.
///
/// For feeds with thousands of episodes, this avoids building the entire XML
/// string in memory. Instead, XML chunks are streamed directly to the client.
///
/// ```swift
/// app.get("large-feed.xml") { req -> Response in
///     let feed = try await loadLargeFeed(on: req.db)
///     return try await StreamingFeedResponse.stream(feed, for: req)
/// }
/// ```
public struct StreamingFeedResponse: Sendable {

    /// Creates a streaming HTTP response for a podcast feed.
    ///
    /// Uses `StreamingFeedGenerator` to produce XML chunks that are
    /// written to the response body as they are generated.
    ///
    /// - Parameters:
    ///   - feed: The podcast feed to stream.
    ///   - request: The Vapor request (for configuration access).
    /// - Returns: A streaming HTTP response with chunked XML.
    public static func stream(_ feed: PodcastFeed, for request: Request) async throws -> Response {
        let config = request.application.feedConfiguration
        let generator = StreamingFeedGenerator(prettyPrint: config.prettyPrint)

        let response = Response(status: .ok)
        response.headers.contentType = config.contentType
        if let generatorName = config.generatorHeader {
            response.headers.add(name: "X-Generator", value: generatorName)
        }

        let maxAge = config.ttl.totalSeconds
        response.headers.add(name: .cacheControl, value: "public, max-age=\(maxAge)")

        response.body = .init(managedAsyncStream: { writer in
            for try await chunk in generator.generate(feed) {
                try await writer.writeBuffer(ByteBuffer(string: chunk))
            }
        })

        return response
    }
}
