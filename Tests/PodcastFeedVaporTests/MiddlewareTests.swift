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

import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Podcast Feed Middleware Tests")
struct MiddlewareTests {
    @Test("Adds X-Generator to RSS responses")
    func addsGeneratorToRSS() async throws {
        try await withApp(
            configure: { app in
                app.middleware.use(PodcastFeedMiddleware())
                app.get(
                    "feed.xml",
                    use: { _ -> Response in
                        Response.xml("<rss><channel><title>Test</title></channel></rss>")
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let generator = res.headers["X-Generator"]
                        #expect(generator.first == "PodcastFeedMaker")
                    }
                )
            }
        )
    }

    @Test("Does not add X-Generator to non-RSS responses")
    func skipsNonRSSResponses() async throws {
        try await withApp(
            configure: { app in
                app.middleware.use(PodcastFeedMiddleware())
                app.get(
                    "api", "data",
                    use: { _ -> [String: String] in
                        ["key": "value"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "api/data",
                    afterResponse: { res in
                        #expect(res.headers["X-Generator"].isEmpty)
                    }
                )
            }
        )
    }

    @Test("Does not duplicate X-Generator if already present")
    func noDuplicateGenerator() async throws {
        try await withApp(
            configure: { app in
                app.middleware.use(PodcastFeedMiddleware())
                app.get(
                    "feed.xml",
                    use: { _ -> Response in
                        let response = Response.xml("<rss></rss>")
                        response.headers.add(name: "X-Generator", value: "ExistingGen")
                        return response
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let generators = res.headers["X-Generator"]
                        #expect(generators.count == 1)
                        #expect(generators.first == "ExistingGen")
                    }
                )
            }
        )
    }

    @Test("Respects custom generator header name")
    func customGeneratorName() async throws {
        try await withApp(
            configure: { app in
                app.feedConfiguration.generatorHeader = "CustomGen"
                app.middleware.use(PodcastFeedMiddleware())
                app.get(
                    "feed.xml",
                    use: { _ -> Response in
                        Response.xml("<rss></rss>")
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let generator = res.headers["X-Generator"]
                        #expect(generator.first == "CustomGen")
                    }
                )
            }
        )
    }

    @Test("No X-Generator when disabled")
    func disabledGenerator() async throws {
        try await withApp(
            configure: { app in
                app.feedConfiguration.generatorHeader = nil
                app.middleware.use(PodcastFeedMiddleware())
                app.get(
                    "feed.xml",
                    use: { _ -> Response in
                        Response.xml("<rss></rss>")
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers["X-Generator"].isEmpty)
                    }
                )
            }
        )
    }
}
