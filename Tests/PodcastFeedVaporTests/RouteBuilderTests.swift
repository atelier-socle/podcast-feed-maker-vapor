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

@Suite("Feed Route Builder Tests")
struct RouteBuilderTests {
    @Test("podcastFeed registers GET route that returns XML")
    func registersRoute() async throws {
        try await withApp(
            configure: { app in
                app.podcastFeed(
                    "feed.xml",
                    handler: { _ in
                        try makeTestFeed()
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

    @Test("podcastFeed with multiple path components")
    func multiplePathComponents() async throws {
        try await withApp(
            configure: { app in
                app.podcastFeed(
                    "shows", "feed.xml",
                    handler: { _ in
                        try makeTestFeed()
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "shows/feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("<rss"))
                    }
                )
            }
        )
    }

    @Test("podcastFeed handler receives Request")
    func handlerReceivesRequest() async throws {
        try await withApp(
            configure: { app in
                app.podcastFeed(
                    "feed.xml",
                    handler: { req in
                        let customTitle = req.query[String.self, at: "title"] ?? "Default"
                        return try makeTestFeed(title: customTitle)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml?title=MyPodcast",
                    afterResponse: { res in
                        #expect(res.body.string.contains("MyPodcast"))
                    }
                )
            }
        )
    }

    @Test("podcastFeed applies FeedConfiguration")
    func appliesConfiguration() async throws {
        try await withApp(
            configure: { app in
                app.feedConfiguration.generatorHeader = "TestGen"
                app.feedConfiguration.ttl = .hours(1)
                app.podcastFeed(
                    "feed.xml",
                    handler: { _ in
                        try makeTestFeed()
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers["X-Generator"].first == "TestGen")
                        #expect(res.headers[.cacheControl].first == "public, max-age=3600")
                    }
                )
            }
        )
    }

    @Test("podcastFeed handler errors propagate")
    func handlerErrorsPropagateAs500() async throws {
        try await withApp(
            configure: { app in
                app.podcastFeed(
                    "feed.xml",
                    handler: { _ in
                        throw Abort(.internalServerError, reason: "Feed generation failed")
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .internalServerError)
                    }
                )
            }
        )
    }
}
