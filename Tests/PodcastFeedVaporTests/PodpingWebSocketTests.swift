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

@testable import PodcastFeedVapor

@Suite("Podping WebSocket — Edge Cases")
struct PodpingWebSocketEdgeCases {

    // MARK: - PodpingMessage

    @Test("Notification with all media types")
    func allMediaTypes() {
        for medium in PodpingMedium.allCases {
            let message = PodpingMessage.notification(
                feedURL: "https://example.com/feed.xml",
                medium: medium
            )
            #expect(message.medium == medium)
        }
    }

    @Test("Notification with all reasons")
    func allReasons() {
        for reason in PodpingReason.allCases {
            let message = PodpingMessage.notification(
                feedURL: "https://example.com/feed.xml",
                reason: reason
            )
            #expect(message.reason == reason)
        }
    }

    @Test("Message with nil optional fields")
    func nilOptionalFields() throws {
        let message = PodpingMessage(kind: .welcome)
        #expect(message.feedURL == nil)
        #expect(message.feedURLs == nil)
        #expect(message.reason == nil)
        #expect(message.medium == nil)
        #expect(message.timestamp == nil)
        #expect(message.message == nil)

        // Should encode/decode without error
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(PodpingMessage.self, from: data)
        #expect(decoded.kind == .welcome)
    }

    @Test("Decode subscribe message from raw JSON")
    func decodeFromRawJSON() throws {
        let json = """
            {"kind":"subscribe","feedURLs":["https://a.com/feed.xml","https://b.com/feed.xml"]}
            """
        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(PodpingMessage.self, from: data)
        #expect(message.kind == .subscribe)
        #expect(message.feedURLs?.count == 2)
    }

    @Test("Decode unknown kind — throws decoding error")
    func unknownKind() {
        let json = """
            {"kind":"unknown_type"}
            """
        let data = Data(json.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PodpingMessage.self, from: data)
        }
    }

    @Test("PodpingMessage Equatable — same content is equal")
    func equatable() {
        let a = PodpingMessage(kind: .welcome, message: "hello")
        let b = PodpingMessage(kind: .welcome, message: "hello")
        #expect(a == b)
    }

    @Test("PodpingMessage Equatable — different content is not equal")
    func notEquatable() {
        let a = PodpingMessage(kind: .welcome, message: "hello")
        let b = PodpingMessage(kind: .welcome, message: "world")
        #expect(a != b)
    }

    // MARK: - PodpingWebSocketManager

    @Test("Manager — remove nonexistent connection does not crash")
    func removeNonexistent() async {
        let manager = PodpingWebSocketManager()
        await manager.removeConnection(UUID())
        let count = await manager.connectionCount
        #expect(count == 0)
    }

    @Test("Manager — subscriptions for nonexistent connection returns nil")
    func subscriptionsNonexistent() async {
        let manager = PodpingWebSocketManager()
        let subs = await manager.subscriptions(for: UUID())
        #expect(subs == nil)
    }

    @Test("Manager — subscribe to nonexistent connection is no-op")
    func subscribeNonexistent() async {
        let manager = PodpingWebSocketManager()
        await manager.subscribe(
            connectionID: UUID(),
            feedURLs: ["https://example.com/feed.xml"]
        )
        let count = await manager.connectionCount
        #expect(count == 0)
    }

    @Test("Manager — broadcast with no connections does not crash")
    func broadcastEmpty() async {
        let manager = PodpingWebSocketManager()
        await manager.broadcast(feedURL: "https://example.com/feed.xml")
        // No crash, no error
    }
}
