import PodcastFeedMaker

/// A type that can be converted into a ``PodcastFeed``.
///
/// Conform your Fluent models (or any type) to this protocol to enable
/// automatic feed generation from database records.
///
/// ```swift
/// extension Show: FeedMappable {
///     func toPodcastFeed() -> PodcastFeed {
///         PodcastFeed(version: "2.0", namespaces: PodcastNamespace.allStandard, channel: channel)
///     }
/// }
/// ```
public protocol FeedMappable: Sendable {
    /// Converts this instance into a ``PodcastFeed``.
    func toPodcastFeed() -> PodcastFeed
}

/// A type that can be converted into a podcast feed ``Channel``.
///
/// ```swift
/// extension Show: ChannelMappable {
///     func toChannel(items: [Item]) -> Channel {
///         Channel(title: name, link: websiteURL, description: summary, items: items)
///     }
/// }
/// ```
public protocol ChannelMappable: Sendable {
    /// Converts this instance into a ``Channel`` with the given items.
    ///
    /// - Parameter items: The episode items to include in the channel.
    /// - Returns: A configured ``Channel``.
    func toChannel(items: [Item]) -> Channel
}

/// A type that can be converted into a podcast feed ``Item``.
///
/// ```swift
/// extension Episode: ItemMappable {
///     func toItem() -> Item {
///         Item(title: title, enclosure: Enclosure(url: audioURL, length: fileSize, type: "audio/mpeg"))
///     }
/// }
/// ```
public protocol ItemMappable: Sendable {
    /// Converts this instance into an ``Item``.
    func toItem() -> Item
}

extension Array where Element: ItemMappable {
    /// Converts an array of `ItemMappable` elements into an array of ``Item``.
    public func toItems() -> [Item] {
        map { $0.toItem() }
    }
}
