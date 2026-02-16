import Foundation
import PodcastFeedMaker

/// Creates a minimal valid PodcastFeed for testing.
func makeTestFeed(
    title: String = "Test Podcast",
    itemCount: Int = 1
) throws -> PodcastFeed {
    let items: [Item] = try (0..<itemCount).map { index in
        guard let audioURL = URL(string: "https://example.com/ep\(index + 1).mp3") else {
            throw URLError(.badURL)
        }
        return Item(
            title: "Episode \(index + 1)",
            enclosure: Enclosure(url: audioURL, length: 1_000_000, type: "audio/mpeg")
        )
    }
    guard let linkURL = URL(string: "https://example.com") else {
        throw URLError(.badURL)
    }
    let channel = Channel(
        title: title,
        link: linkURL,
        description: "A test feed",
        items: items
    )
    return PodcastFeed(version: "2.0", namespaces: [], channel: channel)
}
