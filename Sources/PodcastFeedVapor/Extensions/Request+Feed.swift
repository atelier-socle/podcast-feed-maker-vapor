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

extension Request {
    /// Encodes a `PodcastFeed` into an XML response using the app's feed configuration.
    ///
    /// ```swift
    /// app.get("feed.xml") { req in
    ///     try req.feedResponse(myFeed)
    /// }
    /// ```
    ///
    /// - Parameter feed: The podcast feed to encode.
    /// - Returns: An HTTP response with XML body and proper headers.
    /// - Throws: `GeneratorError` if the feed cannot be serialized.
    public func feedResponse(_ feed: PodcastFeed) throws -> Response {
        try FeedResponseEncoder.encode(feed, for: self)
    }
}
