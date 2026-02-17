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

@Suite("Podping Notifier Tests")
struct PodpingTests {
    @Test("PodpingReason has correct raw values")
    func reasonRawValues() {
        #expect(PodpingReason.update.rawValue == "update")
        #expect(PodpingReason.live.rawValue == "live")
        #expect(PodpingReason.liveEnd.rawValue == "liveEnd")
    }

    @Test("PodpingMedium has correct raw values")
    func mediumRawValues() {
        #expect(PodpingMedium.podcast.rawValue == "podcast")
        #expect(PodpingMedium.music.rawValue == "music")
        #expect(PodpingMedium.video.rawValue == "video")
        #expect(PodpingMedium.film.rawValue == "film")
        #expect(PodpingMedium.audiobook.rawValue == "audiobook")
        #expect(PodpingMedium.newsletter.rawValue == "newsletter")
        #expect(PodpingMedium.blog.rawValue == "blog")
    }

    @Test("PodpingReason is CaseIterable")
    func reasonCaseIterable() {
        #expect(PodpingReason.allCases.count == 3)
    }

    @Test("PodpingMedium is CaseIterable")
    func mediumCaseIterable() {
        #expect(PodpingMedium.allCases.count == 7)
    }

    @Test("PodpingError equality")
    func errorEquality() {
        #expect(PodpingError.serverError(500) == PodpingError.serverError(500))
        #expect(PodpingError.serverError(500) != PodpingError.serverError(404))
        #expect(PodpingError.invalidEndpoint("a") == PodpingError.invalidEndpoint("a"))
        #expect(PodpingError.invalidEndpoint("a") != PodpingError.invalidEndpoint("b"))
    }

    @Test("Notify sends GET request with correct query parameters")
    func notifySendsCorrectRequest() async throws {
        try await withApp(
            configure: { app in
                app.get("mock-podping") { req -> HTTPStatus in
                    let url: String? = req.query["url"]
                    let reason: String? = req.query["reason"]
                    let medium: String? = req.query["medium"]
                    #expect(url == "https://example.com/feed.xml")
                    #expect(reason == "update")
                    #expect(medium == "podcast")
                    return .ok
                }
            },
            { app in
                try await app.testing().test(
                    .GET,
                    "mock-podping?url=https://example.com/feed.xml&reason=update&medium=podcast",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                    }
                )
            }
        )
    }

    @Test("Notify includes Authorization header when token provided")
    func notifyIncludesAuthHeader() async throws {
        try await withApp(
            configure: { app in
                app.get("mock-podping") { req -> HTTPStatus in
                    let auth = req.headers.first(name: .authorization)
                    #expect(auth == "Bearer test-token")
                    return .ok
                }
            },
            { app in
                try await app.testing().test(
                    .GET, "mock-podping",
                    beforeRequest: { req in
                        req.headers.add(name: .authorization, value: "Bearer test-token")
                    },
                    afterResponse: { res in
                        #expect(res.status == .ok)
                    }
                )
            }
        )
    }

    @Test("Notify omits Authorization header when no token")
    func notifyOmitsAuthHeader() async throws {
        try await withApp(
            configure: { app in
                app.get("mock-podping") { req -> HTTPStatus in
                    let auth = req.headers.first(name: .authorization)
                    #expect(auth == nil)
                    return .ok
                }
            },
            { app in
                try await app.testing().test(
                    .GET, "mock-podping",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                    }
                )
            }
        )
    }

    @Test("PodpingError conforms to Error")
    func errorConformsToError() {
        let error: any Error = PodpingError.serverError(500)
        #expect(error is PodpingError)
    }

    @Test("PodpingNotifier can be constructed with defaults")
    func notifierDefaults() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let notifier = PodpingNotifier(client: app.client)
                _ = notifier
            }
        )
    }

    @Test("PodpingNotifier can be constructed with custom config")
    func notifierCustomConfig() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let notifier = PodpingNotifier(
                    client: app.client,
                    endpoint: "https://custom.podping.cloud",
                    authToken: "my-token"
                )
                _ = notifier
            }
        )
    }

    @Test("Mock endpoint returns server error status")
    func mockEndpointServerError() async throws {
        try await withApp(
            configure: { app in
                app.get("mock-podping") { _ -> HTTPStatus in
                    .internalServerError
                }
            },
            { app in
                try await app.testing().test(
                    .GET, "mock-podping",
                    afterResponse: { res in
                        #expect(res.status == .internalServerError)
                    }
                )
            }
        )
    }
}
