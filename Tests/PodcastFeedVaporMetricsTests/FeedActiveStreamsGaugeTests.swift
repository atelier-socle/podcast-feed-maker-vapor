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

import MetricsTestKit
import Testing

@testable import CoreMetrics
@testable import PodcastFeedVaporMetrics

extension AllMetricsTests {

    @Suite("FeedActiveStreamsGauge — Edge Cases")
    struct FeedActiveStreamsGaugeEdgeCases {

        @Test("Concurrent increment/decrement from multiple tasks")
        func concurrentAccess() async {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let gauge = FeedActiveStreamsGauge()

            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<50 {
                    group.addTask {
                        await gauge.increment()
                    }
                }
            }

            var count = await gauge.current
            #expect(count == 50)

            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<50 {
                    group.addTask {
                        await gauge.decrement()
                    }
                }
            }

            count = await gauge.current
            #expect(count == 0)
        }

        @Test("Gauge metric value correctness after multiple operations")
        func gaugeValueCorrectness() async {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let gauge = FeedActiveStreamsGauge()
            await gauge.increment()
            await gauge.increment()
            await gauge.increment()
            await gauge.decrement()

            let count = await gauge.current
            #expect(count == 2)

            let recorders = metrics.recorders.filter { $0.label == "pfv_feed_active_streams" }
            #expect(!recorders.isEmpty)
            // Last recorded value should be 2
            #expect(recorders.first?.lastValue == 2.0)
        }

        @Test("Multiple decrements below zero — always clamped")
        func multipleDecrementsBelowZero() async {
            let metrics = TestMetrics()
            MetricsSystem.bootstrapInternal(metrics)

            let gauge = FeedActiveStreamsGauge()
            await gauge.decrement()
            await gauge.decrement()
            await gauge.decrement()
            let count = await gauge.current
            #expect(count == 0)
        }
    }
}
