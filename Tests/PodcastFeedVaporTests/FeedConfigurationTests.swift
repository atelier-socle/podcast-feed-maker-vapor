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
