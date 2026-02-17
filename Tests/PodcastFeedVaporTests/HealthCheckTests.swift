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

import Foundation
import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Health Check Tests")
struct HealthCheckTests {
    @Test("GET /health returns 200 with ok status")
    func healthEndpoint() async throws {
        try await withApp(
            configure: { app in
                app.healthCheck()
            },
            { app in
                try await app.testing().test(
                    .GET, "health",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("ok"))
                    }
                )
            }
        )
    }

    @Test("Health response includes version")
    func includesVersion() async throws {
        try await withApp(
            configure: { app in
                app.healthCheck()
            },
            { app in
                try await app.testing().test(
                    .GET, "health",
                    afterResponse: { res in
                        let body = res.body.string
                        #expect(body.contains("version"))
                        #expect(body.contains("0.2.0"))
                    }
                )
            }
        )
    }

    @Test("Health response includes uptime")
    func includesUptime() async throws {
        try await withApp(
            configure: { app in
                app.healthCheck()
            },
            { app in
                try await app.testing().test(
                    .GET, "health",
                    afterResponse: { res in
                        let body = res.body.string
                        #expect(body.contains("uptime"))
                    }
                )
            }
        )
    }

    @Test("Custom health path")
    func customHealthPath() async throws {
        try await withApp(
            configure: { app in
                app.healthCheck(path: "status")
            },
            { app in
                try await app.testing().test(
                    .GET, "status",
                    afterResponse: { res in
                        #expect(res.status == .ok)
                        #expect(res.body.string.contains("ok"))
                    }
                )
            }
        )
    }

    @Test("HealthResponse is Codable")
    func healthResponseCodable() throws {
        let response = HealthResponse(status: "ok", version: "0.2.0", uptime: 3600)
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HealthResponse.self, from: data)
        #expect(decoded.status == "ok")
        #expect(decoded.version == "0.2.0")
        #expect(decoded.uptime == 3600)
    }
}
