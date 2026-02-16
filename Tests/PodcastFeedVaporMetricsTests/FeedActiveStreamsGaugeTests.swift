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
