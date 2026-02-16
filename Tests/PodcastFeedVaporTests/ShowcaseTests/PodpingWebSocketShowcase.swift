import Foundation
import Testing
import VaporTesting

@testable import PodcastFeedVapor

// MARK: - PodpingMessage Showcase

@Suite("Podping WebSocket — Message Types")
struct PodpingMessageShowcase {

    @Test("Notification message — has feedURL, reason, medium, timestamp")
    func notificationMessage() throws {
        let message = PodpingMessage.notification(
            feedURL: "https://example.com/feed.xml",
            reason: .update,
            medium: .podcast
        )
        #expect(message.kind == .notification)
        #expect(message.feedURL == "https://example.com/feed.xml")
        #expect(message.reason == .update)
        #expect(message.medium == .podcast)
        #expect(message.timestamp != nil)
    }

    @Test("Welcome message — has kind and message")
    func welcomeMessage() {
        let message = PodpingMessage.welcome()
        #expect(message.kind == .welcome)
        #expect(message.message == "Connected to Podping WebSocket")
    }

    @Test("Subscribed message — specific feeds")
    func subscribedSpecific() {
        let message = PodpingMessage.subscribed(
            feedURLs: ["https://a.com/feed.xml", "https://b.com/feed.xml"]
        )
        #expect(message.kind == .subscribed)
        #expect(message.feedURLs?.count == 2)
        #expect(message.message == "Subscribed to 2 feed(s)")
    }

    @Test("Subscribed message — all feeds (empty array)")
    func subscribedAll() {
        let message = PodpingMessage.subscribed(feedURLs: [])
        #expect(message.kind == .subscribed)
        #expect(message.feedURLs?.isEmpty == true)
        #expect(message.message == "Subscribed to all feeds")
    }

    @Test("Subscribe request — client to server")
    func subscribeRequest() {
        let message = PodpingMessage(
            kind: .subscribe,
            feedURLs: ["https://example.com/feed.xml"]
        )
        #expect(message.kind == .subscribe)
        #expect(message.feedURLs?.first == "https://example.com/feed.xml")
    }

    @Test("Unsubscribe request — client to server")
    func unsubscribeRequest() {
        let message = PodpingMessage(
            kind: .unsubscribe,
            feedURLs: ["https://example.com/feed.xml"]
        )
        #expect(message.kind == .unsubscribe)
    }

    @Test("JSON round-trip — encode and decode notification")
    func jsonRoundTrip() throws {
        let original = PodpingMessage.notification(
            feedURL: "https://example.com/feed.xml",
            reason: .live,
            medium: .music
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PodpingMessage.self, from: data)
        #expect(decoded.kind == .notification)
        #expect(decoded.feedURL == "https://example.com/feed.xml")
        #expect(decoded.reason == .live)
        #expect(decoded.medium == .music)
        #expect(decoded.timestamp == original.timestamp)
    }

    @Test("MessageKind raw values — match JSON keys")
    func messageKindRawValues() {
        #expect(PodpingMessage.MessageKind.welcome.rawValue == "welcome")
        #expect(PodpingMessage.MessageKind.notification.rawValue == "notification")
        #expect(PodpingMessage.MessageKind.subscribed.rawValue == "subscribed")
        #expect(PodpingMessage.MessageKind.subscribe.rawValue == "subscribe")
        #expect(PodpingMessage.MessageKind.unsubscribe.rawValue == "unsubscribe")
    }
}

// MARK: - PodpingWebSocketManager Showcase

@Suite("Podping WebSocket — Manager")
struct PodpingWebSocketManagerShowcase {

    @Test("New manager — starts with zero connections")
    func emptyManager() async {
        let manager = PodpingWebSocketManager()
        let count = await manager.connectionCount
        #expect(count == 0)
    }

    @Test("Application storage — manager is accessible via app property")
    func applicationStorage() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let manager = app.podpingWebSocketManager
                let count = await manager.connectionCount
                #expect(count == 0)
            }
        )
    }

    @Test("Application storage — same instance returned on multiple accesses")
    func applicationStorageSameInstance() async throws {
        try await withApp(
            configure: { _ in },
            { app in
                let manager1 = app.podpingWebSocketManager
                let manager2 = app.podpingWebSocketManager
                // Both should be the same actor instance
                #expect(manager1 === manager2)
            }
        )
    }

    @Test("WebSocket route registration — does not crash")
    func routeRegistration() async throws {
        try await withApp(
            configure: { app in
                app.podpingWebSocket("podping")
            },
            { _ in
                // Route registered successfully — no crash
            }
        )
    }

    @Test("WebSocket route registration — custom path")
    func customPath() async throws {
        try await withApp(
            configure: { app in
                app.podpingWebSocket("ws", "notifications")
            },
            { _ in }
        )
    }
}
