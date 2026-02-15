import Testing

@testable import PodcastFeedVapor

@Suite("Feed Configuration Tests")
struct FeedConfigurationTests {
    @Test("Default configuration values")
    func defaultValues() {
        let config = FeedConfiguration()
        #expect(config.ttl == .minutes(5))
        #expect(config.gzipEnabled == false)
        #expect(config.prettyPrint == false)
        #expect(config.generatorHeader == "PodcastFeedMaker")
        #expect(config.contentType.type == "application")
        #expect(config.contentType.subType == "rss+xml")
    }

    @Test("CacheControlDuration seconds conversion")
    func durationConversion() {
        #expect(CacheControlDuration.seconds(30).totalSeconds == 30)
        #expect(CacheControlDuration.minutes(5).totalSeconds == 300)
        #expect(CacheControlDuration.hours(1).totalSeconds == 3600)
    }

    @Test("Custom configuration")
    func customValues() {
        let config = FeedConfiguration(
            ttl: .hours(2),
            gzipEnabled: true,
            prettyPrint: true,
            generatorHeader: "MyGenerator"
        )
        #expect(config.ttl == .hours(2))
        #expect(config.gzipEnabled == true)
        #expect(config.prettyPrint == true)
        #expect(config.generatorHeader == "MyGenerator")
    }

    @Test("CacheControlDuration equatable")
    func durationEquatable() {
        #expect(CacheControlDuration.minutes(1) == CacheControlDuration.minutes(1))
        #expect(CacheControlDuration.minutes(1) != CacheControlDuration.seconds(30))
        #expect(CacheControlDuration.hours(1) == CacheControlDuration.hours(1))
        #expect(CacheControlDuration.seconds(60) != CacheControlDuration.minutes(1))
    }
}
