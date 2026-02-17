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
import PodcastFeedMaker
import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Batch Audit Endpoint Tests")
struct BatchAuditTests {
    @Test("Returns 400 when urls parameter is missing")
    func missingURLsParam() async throws {
        try await withApp(
            configure: { app in
                app.batchAudit("feeds", "audit")
            },
            { app in
                try await app.testing().test(
                    .GET, "feeds/audit",
                    afterResponse: { res in
                        #expect(res.status == .badRequest)
                    }
                )
            }
        )
    }

    @Test("Returns 400 when urls parameter is empty")
    func emptyURLsParam() async throws {
        try await withApp(
            configure: { app in
                app.batchAudit("feeds", "audit")
            },
            { app in
                try await app.testing().test(
                    .GET, "feeds/audit?urls=",
                    afterResponse: { res in
                        #expect(res.status == .badRequest)
                    }
                )
            }
        )
    }

    @Test("BatchAuditResult encodes to JSON correctly")
    func encodesToJSON() throws {
        let result = BatchAuditResult(
            url: "https://example.com/feed.xml",
            score: 85,
            grade: "B+",
            recommendationCount: 3
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BatchAuditResult.self, from: data)
        #expect(decoded.url == "https://example.com/feed.xml")
        #expect(decoded.score == 85)
        #expect(decoded.grade == "B+")
        #expect(decoded.recommendationCount == 3)
        #expect(decoded.error == nil)
    }

    @Test("BatchAuditResult failure factory")
    func failureFactory() {
        let result = BatchAuditResult.failure(url: "https://bad.com/feed.xml", error: "parse error")
        #expect(result.url == "https://bad.com/feed.xml")
        #expect(result.score == 0)
        #expect(result.grade == "F")
        #expect(result.recommendationCount == 0)
        #expect(result.error == "parse error")
    }

    @Test("BatchAuditResult success has nil error")
    func successHasNilError() {
        let result = BatchAuditResult(
            url: "https://example.com/feed.xml",
            score: 90,
            grade: "A",
            recommendationCount: 1
        )
        #expect(result.error == nil)
    }

    @Test("BatchAuditResult is decodable")
    func isDecodable() throws {
        let json = """
            {"url":"https://example.com/feed.xml","score":75,"grade":"C+","recommendationCount":5,"error":null}
            """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let result = try decoder.decode(BatchAuditResult.self, from: data)
        #expect(result.url == "https://example.com/feed.xml")
        #expect(result.score == 75)
        #expect(result.grade == "C+")
        #expect(result.recommendationCount == 5)
        #expect(result.error == nil)
    }
}
