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

import NIOEmbedded
import Testing
import VaporTesting

@testable import PodcastFeedVapor
@testable import WebSocketKit

@Suite("Podping WebSocket — Integration")
struct PodpingWebSocketIntegration {

    // MARK: - Manager with real WebSocket connections

    @Test("addConnection — tracks connection and sends welcome")
    func addConnection() async throws {
        let channel = EmbeddedChannel()
        let ws = WebSocket(channel: channel, type: .server)
        let manager = PodpingWebSocketManager()

        let id = await manager.addConnection(ws)
        #expect(await manager.connectionCount == 1)

        let subs = await manager.subscriptions(for: id)
        #expect(subs == Set<String>())

        try await channel.close().get()
    }

    @Test("subscribe — updates subscription set for valid connection")
    func subscribeValid() async throws {
        let channel = EmbeddedChannel()
        let ws = WebSocket(channel: channel, type: .server)
        let manager = PodpingWebSocketManager()

        let id = await manager.addConnection(ws)
        await manager.subscribe(
            connectionID: id,
            feedURLs: ["https://a.com/feed.xml", "https://b.com/feed.xml"]
        )

        let subs = await manager.subscriptions(for: id)
        #expect(subs == Set(["https://a.com/feed.xml", "https://b.com/feed.xml"]))

        try await channel.close().get()
    }

    @Test("unsubscribe — removes feeds from subscription set")
    func unsubscribeValid() async throws {
        let channel = EmbeddedChannel()
        let ws = WebSocket(channel: channel, type: .server)
        let manager = PodpingWebSocketManager()

        let id = await manager.addConnection(ws)
        await manager.subscribe(
            connectionID: id,
            feedURLs: ["https://a.com/feed.xml", "https://b.com/feed.xml"]
        )
        await manager.unsubscribe(connectionID: id, feedURLs: ["https://a.com/feed.xml"])

        let subs = await manager.subscriptions(for: id)
        #expect(subs == Set(["https://b.com/feed.xml"]))

        try await channel.close().get()
    }

    @Test("broadcast — sends to unfiltered connections")
    func broadcastUnfiltered() async throws {
        let channel = EmbeddedChannel()
        let ws = WebSocket(channel: channel, type: .server)
        let manager = PodpingWebSocketManager()

        _ = await manager.addConnection(ws)
        // No subscription = receives all broadcasts
        await manager.broadcast(feedURL: "https://example.com/feed.xml")
        #expect(await manager.connectionCount == 1)

        try await channel.close().get()
    }

    @Test("broadcast — sends only to matching subscribers")
    func broadcastFiltered() async throws {
        let ch1 = EmbeddedChannel()
        let ws1 = WebSocket(channel: ch1, type: .server)
        let ch2 = EmbeddedChannel()
        let ws2 = WebSocket(channel: ch2, type: .server)
        let manager = PodpingWebSocketManager()

        let id1 = await manager.addConnection(ws1)
        let id2 = await manager.addConnection(ws2)

        // ws1 subscribes to feed a, ws2 subscribes to feed b
        await manager.subscribe(connectionID: id1, feedURLs: ["https://a.com/feed.xml"])
        await manager.subscribe(connectionID: id2, feedURLs: ["https://b.com/feed.xml"])

        // Broadcast for feed a — only ws1 matches
        await manager.broadcast(feedURL: "https://a.com/feed.xml")
        #expect(await manager.connectionCount == 2)

        try await ch1.close().get()
        try await ch2.close().get()
    }

    @Test("broadcast — all reasons and media types exercised")
    func broadcastAllVariants() async throws {
        let channel = EmbeddedChannel()
        let ws = WebSocket(channel: channel, type: .server)
        let manager = PodpingWebSocketManager()

        _ = await manager.addConnection(ws)
        await manager.broadcast(
            feedURL: "https://example.com/feed.xml",
            reason: .live,
            medium: .music
        )
        await manager.broadcast(
            feedURL: "https://example.com/feed.xml",
            reason: .liveEnd,
            medium: .video
        )

        try await channel.close().get()
    }

    @Test("removeConnection — decrements count after addConnection")
    func removeDecrements() async throws {
        let channel = EmbeddedChannel()
        let ws = WebSocket(channel: channel, type: .server)
        let manager = PodpingWebSocketManager()

        let id = await manager.addConnection(ws)
        #expect(await manager.connectionCount == 1)

        await manager.removeConnection(id)
        #expect(await manager.connectionCount == 0)

        try await channel.close().get()
    }

    @Test("Multiple connections — connectionCount tracks correctly")
    func multipleConnections() async throws {
        let ch1 = EmbeddedChannel()
        let ws1 = WebSocket(channel: ch1, type: .server)
        let ch2 = EmbeddedChannel()
        let ws2 = WebSocket(channel: ch2, type: .server)
        let ch3 = EmbeddedChannel()
        let ws3 = WebSocket(channel: ch3, type: .server)
        let manager = PodpingWebSocketManager()

        let id1 = await manager.addConnection(ws1)
        _ = await manager.addConnection(ws2)
        _ = await manager.addConnection(ws3)
        #expect(await manager.connectionCount == 3)

        await manager.removeConnection(id1)
        #expect(await manager.connectionCount == 2)

        try await ch1.close().get()
        try await ch2.close().get()
        try await ch3.close().get()
    }

    // MARK: - handleMessage (JSON parsing + dispatch)

    @Test("handleMessage — subscribe via JSON")
    func handleMessageSubscribe() async throws {
        let channel = EmbeddedChannel()
        let ws = WebSocket(channel: channel, type: .server)
        let manager = PodpingWebSocketManager()

        let id = await manager.addConnection(ws)

        let json = #"{"kind":"subscribe","feedURLs":["https://a.com/feed.xml"]}"#
        await manager.handleMessage(json, connectionID: id)

        let subs = await manager.subscriptions(for: id)
        #expect(subs == Set(["https://a.com/feed.xml"]))

        try await channel.close().get()
    }

    @Test("handleMessage — unsubscribe via JSON")
    func handleMessageUnsubscribe() async throws {
        let channel = EmbeddedChannel()
        let ws = WebSocket(channel: channel, type: .server)
        let manager = PodpingWebSocketManager()

        let id = await manager.addConnection(ws)
        await manager.subscribe(
            connectionID: id,
            feedURLs: ["https://a.com/feed.xml", "https://b.com/feed.xml"]
        )

        let json = #"{"kind":"unsubscribe","feedURLs":["https://a.com/feed.xml"]}"#
        await manager.handleMessage(json, connectionID: id)

        let subs = await manager.subscriptions(for: id)
        #expect(subs == Set(["https://b.com/feed.xml"]))

        try await channel.close().get()
    }

    @Test("handleMessage — malformed JSON is silently ignored")
    func handleMessageMalformed() async throws {
        let channel = EmbeddedChannel()
        let ws = WebSocket(channel: channel, type: .server)
        let manager = PodpingWebSocketManager()

        let id = await manager.addConnection(ws)
        await manager.handleMessage("not valid json", connectionID: id)

        let subs = await manager.subscriptions(for: id)
        #expect(subs == Set<String>())

        try await channel.close().get()
    }

    @Test("handleMessage — server message kinds are ignored")
    func handleMessageServerKinds() async throws {
        let channel = EmbeddedChannel()
        let ws = WebSocket(channel: channel, type: .server)
        let manager = PodpingWebSocketManager()

        let id = await manager.addConnection(ws)

        await manager.handleMessage(#"{"kind":"welcome"}"#, connectionID: id)
        await manager.handleMessage(#"{"kind":"notification"}"#, connectionID: id)
        await manager.handleMessage(#"{"kind":"subscribed"}"#, connectionID: id)

        // No state change from server-originated messages
        #expect(await manager.subscriptions(for: id) == Set<String>())

        try await channel.close().get()
    }

    @Test("handleMessage — subscribe without feedURLs is no-op")
    func handleMessageSubscribeNoURLs() async throws {
        let channel = EmbeddedChannel()
        let ws = WebSocket(channel: channel, type: .server)
        let manager = PodpingWebSocketManager()

        let id = await manager.addConnection(ws)
        await manager.handleMessage(#"{"kind":"subscribe"}"#, connectionID: id)

        #expect(await manager.subscriptions(for: id) == Set<String>())

        try await channel.close().get()
    }

    // MARK: - Application storage

    @Test("podpingWebSocketManager setter — custom manager stored")
    func managerSetter() async throws {
        try await withApp(
            configure: { app in
                let custom = PodpingWebSocketManager()
                app.podpingWebSocketManager = custom
            },
            { app in
                let count = await app.podpingWebSocketManager.connectionCount
                #expect(count == 0)
            }
        )
    }
}
