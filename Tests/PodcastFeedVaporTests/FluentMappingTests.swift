import Foundation
import PodcastFeedMaker
import Testing

@testable import PodcastFeedVapor

private struct MockEpisode: ItemMappable {
    let episodeTitle: String
    let audioURL: URL
    let fileSize: Int

    func toItem() -> Item {
        Item(
            title: episodeTitle,
            enclosure: Enclosure(url: audioURL, length: fileSize, type: "audio/mpeg")
        )
    }
}

private struct MockShow: ChannelMappable {
    let name: String
    let websiteURL: URL
    let summary: String

    func toChannel(items: [Item]) -> Channel {
        Channel(
            title: name,
            link: websiteURL,
            description: summary,
            items: items
        )
    }
}

private struct MockPodcast: FeedMappable {
    let show: MockShow
    let episodes: [MockEpisode]

    func toPodcastFeed() -> PodcastFeed {
        let items = episodes.toItems()
        let channel = show.toChannel(items: items)
        return PodcastFeed(version: "2.0", namespaces: [], channel: channel)
    }
}

@Suite("Fluent Mapping Protocol Tests")
struct FluentMappingTests {
    @Test("FeedMappable produces PodcastFeed")
    func feedMappable() throws {
        let websiteURL = try #require(URL(string: "https://example.com"))
        let audioURL = try #require(URL(string: "https://example.com/ep1.mp3"))
        let podcast = MockPodcast(
            show: MockShow(name: "My Show", websiteURL: websiteURL, summary: "A great show"),
            episodes: [MockEpisode(episodeTitle: "Ep 1", audioURL: audioURL, fileSize: 5000)]
        )
        let feed = podcast.toPodcastFeed()
        #expect(feed.channel?.title == "My Show")
        #expect(feed.channel?.items.count == 1)
    }

    @Test("ChannelMappable produces Channel with items")
    func channelMappable() throws {
        let websiteURL = try #require(URL(string: "https://example.com"))
        let show = MockShow(name: "Test Show", websiteURL: websiteURL, summary: "Summary")
        let item = Item(title: "Episode 1")
        let channel = show.toChannel(items: [item])
        #expect(channel.title == "Test Show")
        #expect(channel.description == "Summary")
        #expect(channel.items.count == 1)
        #expect(channel.items.first?.title == "Episode 1")
    }

    @Test("ItemMappable produces Item")
    func itemMappable() throws {
        let audioURL = try #require(URL(string: "https://example.com/audio.mp3"))
        let episode = MockEpisode(episodeTitle: "My Episode", audioURL: audioURL, fileSize: 2000)
        let item = episode.toItem()
        #expect(item.title == "My Episode")
        #expect(item.enclosure?.type == "audio/mpeg")
        #expect(item.enclosure?.length == 2000)
    }

    @Test("Array of ItemMappable converts to Items")
    func arrayToItems() throws {
        let url1 = try #require(URL(string: "https://example.com/1.mp3"))
        let url2 = try #require(URL(string: "https://example.com/2.mp3"))
        let episodes = [
            MockEpisode(episodeTitle: "Ep 1", audioURL: url1, fileSize: 1000),
            MockEpisode(episodeTitle: "Ep 2", audioURL: url2, fileSize: 2000)
        ]
        let items = episodes.toItems()
        #expect(items.count == 2)
        #expect(items[0].title == "Ep 1")
        #expect(items[1].title == "Ep 2")
    }

    @Test("Empty array converts to empty Items")
    func emptyArrayToItems() {
        let episodes: [MockEpisode] = []
        let items = episodes.toItems()
        #expect(items.isEmpty)
    }
}
