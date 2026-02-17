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

@Suite("Feed Serving — Route Builder DSL")
struct RouteBuilderShowcase {

    @Test("Simple feed route — app.podcastFeed('feed.xml')")
    func simpleFeedRoute() async throws {
        let feed = try makeTestFeed(title: "Simple Route Podcast")

        try await withApp(
            configure: { app in
                app.podcastFeed("feed.xml") { _ in feed }
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("Simple Route Podcast"))
                    }
                )
            }
        )
    }

    @Test("Nested feed route — multiple path components")
    func nestedFeedRoute() async throws {
        let feed = try makeTestFeed(title: "Nested Podcast")

        try await withApp(
            configure: { app in
                app.podcastFeed("podcasts", "main", "feed.xml") { _ in feed }
            },
            { app in
                try await app.testing().test(
                    .GET, "podcasts/main/feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("Nested Podcast"))
                    }
                )
            }
        )
    }

    @Test("Dynamic feed from request parameters")
    func dynamicFeed() async throws {
        try await withApp(
            configure: { app in
                app.podcastFeed("shows", ":showId", "feed.xml") { req in
                    let showId = req.parameters.get("showId") ?? "unknown"
                    return try makeTestFeed(title: "Show: \(showId)")
                }
            },
            { app in
                try await app.testing().test(
                    .GET, "shows/tech/feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("Show: tech"))
                    }
                )
            }
        )
    }

    @Test("Feed route with middleware group")
    func feedRouteWithMiddleware() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.grouped(FeedCacheMiddleware(ttl: .hours(2))).podcastFeed("feed.xml") { _ in feed }
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.cacheControl].first == "public, max-age=7200")
                        #expect(res.headers.first(name: .eTag) != nil)
                    }
                )
            }
        )
    }
}

@Suite("Feed Serving — Streaming for Large Feeds")
struct StreamingShowcase {

    @Test("Stream feed with StreamingFeedResponse")
    func streamFeed() async throws {
        let feed = try makeTestFeed(title: "Streamed Podcast")

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingFeedResponse.stream(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("Streamed Podcast"))
                    }
                )
            }
        )
    }

    @Test("Streamed feed has correct Content-Type")
    func streamedContentType() async throws {
        let feed = try makeTestFeed()

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingFeedResponse.stream(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let contentType = res.headers.contentType?.serialize() ?? ""
                        #expect(contentType.contains("rss+xml"))
                    }
                )
            }
        )
    }

    @Test("Streamed XML is valid and parseable")
    func streamedXMLParseable() async throws {
        let feed = try makeTestFeed(title: "Parseable Stream")

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingFeedResponse.stream(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let xml = res.body.string
                        #expect(xml.contains("<?xml"))
                        #expect(xml.contains("<rss"))
                        #expect(xml.contains("</rss>"))
                        #expect(xml.contains("Parseable Stream"))
                    }
                )
            }
        )
    }

    @Test("Large feed streaming — 50+ episodes")
    func largeFeedStreaming() async throws {
        let feed = try makeTestFeed(title: "Big Podcast", itemCount: 50)

        try await withApp(
            configure: { app in
                app.get(
                    "feed.xml",
                    use: { req -> Response in
                        try await StreamingFeedResponse.stream(feed, for: req)
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("Episode 1"))
                        #expect(res.body.string.contains("Episode 50"))
                    }
                )
            }
        )
    }
}

@Suite("Feed Serving — Pagination")
struct PaginationShowcase {

    @Test("Parse pagination from query — ?limit=10&offset=20")
    func parsePagination() async throws {
        try await withApp(
            configure: { app in
                app.get(
                    "test",
                    use: { req -> [String: Int] in
                        let pagination = FeedPagination(from: req)
                        return ["limit": pagination.limit, "offset": pagination.offset]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "test?limit=10&offset=20",
                    afterResponse: { res in
                        #expect(res.body.string.contains("\"limit\":10"))
                        #expect(res.body.string.contains("\"offset\":20"))
                    }
                )
            }
        )
    }

    @Test("Default pagination — no query params")
    func defaultPagination() async throws {
        try await withApp(
            configure: { app in
                app.get(
                    "test",
                    use: { req -> [String: Int] in
                        let pagination = FeedPagination(from: req)
                        return ["limit": pagination.limit, "offset": pagination.offset]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "test",
                    afterResponse: { res in
                        #expect(res.body.string.contains("\"limit\":50"))
                        #expect(res.body.string.contains("\"offset\":0"))
                    }
                )
            }
        )
    }

    @Test("Clamping — limit exceeds max")
    func clampedLimit() async throws {
        try await withApp(
            configure: { app in
                app.get(
                    "test",
                    use: { req -> [String: Int] in
                        let pagination = FeedPagination(from: req, maxLimit: 100)
                        return ["limit": pagination.limit]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "test?limit=5000",
                    afterResponse: { res in
                        #expect(res.body.string.contains("\"limit\":100"))
                    }
                )
            }
        )
    }

    @Test("Use pagination to slice episodes in handler")
    func paginatedFeed() async throws {
        try await withApp(
            configure: { app in
                app.podcastFeed("feed.xml") { req in
                    let pagination = FeedPagination(from: req)
                    let fullFeed = try makeTestFeed(title: "Paginated", itemCount: 20)
                    let allItems = fullFeed.channel?.items ?? []
                    let start = min(pagination.offset, allItems.count)
                    let end = min(start + pagination.limit, allItems.count)
                    let sliced = Array(allItems[start..<end])
                    var paginatedFeed = fullFeed
                    paginatedFeed.channel?.items = sliced
                    return paginatedFeed
                }
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml?limit=5&offset=10",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("Episode 11"))
                        #expect(res.body.string.contains("Episode 15"))
                        #expect(!res.body.string.contains("Episode 16"))
                        #expect(!res.body.string.contains("Episode 10"))
                    }
                )
            }
        )
    }
}
