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

@Suite("Response+XML Extension Tests")
struct ResponseXMLTests {
    @Test("Response.xml creates RSS XML response")
    func xmlResponse() {
        let xml = "<rss><channel><title>Test</title></channel></rss>"
        let response = Response.xml(xml)
        #expect(response.status == .ok)
        let contentType = response.headers.contentType?.serialize() ?? ""
        #expect(contentType.contains("rss+xml"))
        #expect(response.body.string == xml)
    }

    @Test("Response.xml with custom status")
    func xmlResponseCustomStatus() {
        let response = Response.xml("<rss></rss>", status: .notFound)
        #expect(response.status == .notFound)
    }
}
