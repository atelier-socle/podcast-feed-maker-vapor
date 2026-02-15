import Foundation
import PodcastFeedMaker
import Testing

@testable import PodcastFeedVapor

// This file does NOT import VaporTesting to avoid Channel name collision
// between PodcastFeedMaker.Channel (struct) and NIO.Channel (protocol).

@Suite("Fluent Integration — Database Model to Feed Mapping")
struct FluentMappingShowcase {

    private struct MockShow: FeedMappable {
        let title: String
        let link: URL
        let episodes: [MockEpisode]

        func toPodcastFeed() -> PodcastFeed {
            let items = episodes.toItems()
            let channel = Channel(
                title: title,
                link: link,
                description: "A mock show",
                items: items
            )
            return PodcastFeed(version: "2.0", namespaces: [], channel: channel)
        }
    }

    private struct MockChannel: ChannelMappable {
        let title: String
        let link: URL
        let description: String
        let language: String

        func toChannel(items: [Item]) -> Channel {
            Channel(
                title: title,
                link: link,
                description: description,
                language: language,
                items: items
            )
        }
    }

    private struct MockEpisode: ItemMappable {
        let title: String
        let audioURL: URL

        func toItem() -> Item {
            Item(
                title: title,
                enclosure: Enclosure(url: audioURL, length: 1_000_000, type: "audio/mpeg")
            )
        }
    }

    @Test("FeedMappable — map a show model to PodcastFeed")
    func feedMappable() throws {
        let audioURL = try #require(URL(string: "https://example.com/pilot.mp3"))
        let link = try #require(URL(string: "https://example.com"))
        let ep = MockEpisode(title: "Pilot", audioURL: audioURL)
        let show = MockShow(title: "Tech Talk", link: link, episodes: [ep])
        let feed = show.toPodcastFeed()
        #expect(feed.channel?.title == "Tech Talk")
        #expect(feed.channel?.items.count == 1)
    }

    @Test("ChannelMappable — map channel properties")
    func channelMappable() throws {
        let link = try #require(URL(string: "https://example.com"))
        let channel = MockChannel(title: "News Daily", link: link, description: "Daily news", language: "en")
        let result = channel.toChannel(items: [])
        #expect(result.title == "News Daily")
        #expect(result.description == "Daily news")
        #expect(result.language == "en")
    }

    @Test("ItemMappable — map episode model to RSS item")
    func itemMappable() throws {
        let audioURL = try #require(URL(string: "https://example.com/ep1.mp3"))
        let ep = MockEpisode(title: "Episode 1", audioURL: audioURL)
        let item = ep.toItem()
        #expect(item.title == "Episode 1")
        #expect(item.enclosure?.url.absoluteString == "https://example.com/ep1.mp3")
    }

    @Test("Array.toItems() — batch convert episodes")
    func arrayToItems() throws {
        let url1 = try #require(URL(string: "https://example.com/1.mp3"))
        let url2 = try #require(URL(string: "https://example.com/2.mp3"))
        let episodes = [
            MockEpisode(title: "Ep 1", audioURL: url1),
            MockEpisode(title: "Ep 2", audioURL: url2)
        ]
        let items = episodes.toItems()
        #expect(items.count == 2)
        #expect(items[0].title == "Ep 1")
        #expect(items[1].title == "Ep 2")
    }

    @Test("Full pipeline — models → feed → FeedGenerator → XML string")
    func fullPipeline() throws {
        let audioURL = try #require(URL(string: "https://example.com/launch.mp3"))
        let link = try #require(URL(string: "https://example.com"))
        let ep = MockEpisode(title: "Launch", audioURL: audioURL)
        let show = MockShow(title: "Startup Pod", link: link, episodes: [ep])
        let feed = show.toPodcastFeed()
        let generator = FeedGenerator()
        let xml = try generator.generate(feed)
        #expect(xml.contains("Startup Pod"))
        #expect(xml.contains("Launch"))
    }
}
