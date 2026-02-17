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

@Suite("CORS Feed Middleware Tests")
struct CORSMiddlewareTests {
    @Test("Adds CORS headers with wildcard origin by default")
    func wildcardOrigin() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware()).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowOrigin].first == "*")
                    }
                )
            }
        )
    }

    @Test("Handles preflight OPTIONS request")
    func preflightOptions() async throws {
        try await withApp(
            configure: { app in
                app.middleware.use(CORSFeedMiddleware())
                app.get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .OPTIONS, "feed.xml",
                    afterResponse: { res in
                        #expect(res.status == .noContent)
                        #expect(res.headers[.accessControlAllowOrigin].first == "*")
                    }
                )
            }
        )
    }

    @Test("Allows specific origins")
    func specificOrigin() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware(allowedOrigins: ["https://myapp.com"])).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    beforeRequest: { req in
                        req.headers.replaceOrAdd(name: .origin, value: "https://myapp.com")
                    },
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowOrigin].first == "https://myapp.com")
                    }
                )
            }
        )
    }

    @Test("Rejects non-allowed origins")
    func rejectsNonAllowedOrigin() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware(allowedOrigins: ["https://myapp.com"])).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    beforeRequest: { req in
                        req.headers.replaceOrAdd(name: .origin, value: "https://evil.com")
                    },
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowOrigin].isEmpty)
                    }
                )
            }
        )
    }

    @Test("Includes allowed methods")
    func allowedMethods() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware()).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let methods = res.headers[.accessControlAllowMethods].first ?? ""
                        #expect(methods.contains("GET"))
                        #expect(methods.contains("HEAD"))
                        #expect(methods.contains("OPTIONS"))
                    }
                )
            }
        )
    }

    @Test("Includes allowed headers")
    func allowedHeaders() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware()).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        let headers = res.headers[.accessControlAllowHeaders].first ?? ""
                        #expect(headers.contains("If-None-Match"))
                        #expect(headers.contains("If-Modified-Since"))
                    }
                )
            }
        )
    }

    @Test("Max-Age header present")
    func maxAgeHeader() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware()).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.accessControlMaxAge].first == "86400")
                    }
                )
            }
        )
    }

    @Test("Credentials header when enabled")
    func credentialsEnabled() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware(allowCredentials: true)).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowCredentials].first == "true")
                    }
                )
            }
        )
    }

    @Test("No credentials header when disabled")
    func credentialsDisabled() async throws {
        try await withApp(
            configure: { app in
                app.grouped(CORSFeedMiddleware()).get(
                    "feed.xml",
                    use: { _ -> [String: String] in
                        ["status": "ok"]
                    })
            },
            { app in
                try await app.testing().test(
                    .GET, "feed.xml",
                    afterResponse: { res in
                        #expect(res.headers[.accessControlAllowCredentials].isEmpty)
                    }
                )
            }
        )
    }
}
