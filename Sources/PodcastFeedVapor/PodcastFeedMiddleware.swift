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

import Vapor

/// Middleware that adds podcast feed headers to responses.
///
/// When registered globally, this middleware adds the `X-Generator` header
/// and ensures proper cache headers on all responses that have an RSS content type.
///
/// ```swift
/// app.middleware.use(PodcastFeedMiddleware())
/// ```
public struct PodcastFeedMiddleware: AsyncMiddleware, Sendable {

    /// Creates a new podcast feed middleware.
    public init() {}

    /// Processes the request through the middleware chain, adding feed headers to RSS responses.
    ///
    /// - Parameters:
    ///   - request: The incoming request.
    ///   - next: The next responder in the chain.
    /// - Returns: The response, potentially with added feed headers.
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        let config = request.application.feedConfiguration

        guard let contentType = response.headers.contentType,
            contentType.subType.contains("rss") || contentType.subType.contains("xml")
        else {
            return response
        }

        if let generatorName = config.generatorHeader,
            !response.headers.contains(name: "X-Generator")
        {
            response.headers.add(name: "X-Generator", value: generatorName)
        }

        return response
    }
}
