# Fluent Integration

Protocol-based mapping from database models to podcast feeds.

## Overview

PodcastFeedVapor defines three protocols for converting your types into `PodcastFeed`, `Channel`, and `Item` objects. The protocols are pure Swift with no Fluent dependency — they work with any type, including Fluent models, plain structs, or DTOs.

### FeedMappable

Conform your show model to ``FeedMappable`` to convert it directly into a `PodcastFeed`:

```swift
extension Show: FeedMappable {
    func toPodcastFeed() -> PodcastFeed {
        let items = episodes.toItems()
        let channel = Channel(
            title: title,
            link: websiteURL,
            description: summary,
            items: items
        )
        return PodcastFeed(version: "2.0", namespaces: [], channel: channel)
    }
}
```

### ChannelMappable

Conform to ``ChannelMappable`` to map properties to a `Channel` independently from items:

```swift
extension Show: ChannelMappable {
    func toChannel(items: [Item]) -> Channel {
        Channel(
            title: name,
            link: websiteURL,
            description: summary,
            language: "en",
            items: items
        )
    }
}
```

### ItemMappable

Conform to ``ItemMappable`` for episode-to-item mapping:

```swift
extension Episode: ItemMappable {
    func toItem() -> Item {
        Item(
            title: title,
            enclosure: Enclosure(
                url: audioURL,
                length: fileSize,
                type: "audio/mpeg"
            )
        )
    }
}
```

### Batch Conversion

Convert an array of `ItemMappable` elements into `[Item]` with the `toItems()` extension:

```swift
let episodes: [Episode] = try await Episode.query(on: req.db).all()
let items = episodes.toItems()
```

### Full Pipeline

Combine the protocols for a complete model-to-XML pipeline:

```swift
let show = try await Show.find(showId, on: req.db)
let feed = show.toPodcastFeed()
let xml = try FeedGenerator().generate(feed)
```

Or use it with the route builder:

```swift
app.podcastFeed("shows", ":showId", "feed.xml") { req in
    let show = try await Show.find(req.parameters.require("showId"), on: req.db)
    return show.toPodcastFeed()
}
```

## Next Steps

- <doc:FeedServingGuide> — Route builder DSL and streaming
- <doc:AdvancedFeatures> — Podping, batch audit, and health check
