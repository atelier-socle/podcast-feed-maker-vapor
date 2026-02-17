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
import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Request+Feed Extension Tests")
struct RequestFeedTests {
    @Test("req.feedResponse returns XML response")
    func feedResponseReturnsXML() async throws {
        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        let feed = try makeTestFeed()
                        return try req.feedResponse(feed)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        let contentType = res.headers.contentType?.serialize() ?? ""
                        #expect(contentType.contains("rss+xml"))
                        #expect(res.body.string.contains("<rss"))
                    }
                )
            }
        )
    }

    @Test("req.feedResponse uses app configuration")
    func feedResponseUsesConfig() async throws {
        try await withApp(
            configure: { app in
                app.feedConfiguration.generatorHeader = "CustomApp"
                app.feedConfiguration.ttl = .seconds(120)
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        let feed = try makeTestFeed()
                        return try req.feedResponse(feed)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers["X-Generator"].first == "CustomApp")
                        #expect(res.headers[.cacheControl].first == "public, max-age=120")
                    }
                )
            }
        )
    }
}
