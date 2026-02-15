// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "podcast-feed-maker-vapor",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PodcastFeedVapor", targets: ["PodcastFeedVapor"]),
        .library(name: "PodcastFeedVaporRedis", targets: ["PodcastFeedVaporRedis"]),
        .library(name: "PodcastFeedVaporQueues", targets: ["PodcastFeedVaporQueues"])
    ],
    dependencies: [
        .package(url: "https://github.com/atelier-socle/podcast-feed-maker.git", from: "0.2.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.121.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/queues.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0")
    ],
    targets: [
        // Core — PodcastFeedMaker + Vapor + Fluent (no Redis/Queues)
        .target(
            name: "PodcastFeedVapor",
            dependencies: [
                .product(name: "PodcastFeedMaker", package: "podcast-feed-maker"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent")
            ]
        ),
        // Redis cache extension
        .target(
            name: "PodcastFeedVaporRedis",
            dependencies: [
                "PodcastFeedVapor",
                .product(name: "Redis", package: "redis")
            ]
        ),
        // Queue workers extension
        .target(
            name: "PodcastFeedVaporQueues",
            dependencies: [
                "PodcastFeedVapor",
                .product(name: "Queues", package: "queues"),
                .product(name: "QueuesRedisDriver", package: "queues-redis-driver")
            ]
        ),
        // Core tests
        .testTarget(
            name: "PodcastFeedVaporTests",
            dependencies: [
                "PodcastFeedVapor",
                .product(name: "VaporTesting", package: "vapor")
            ]
        ),
        // Redis tests
        .testTarget(
            name: "PodcastFeedVaporRedisTests",
            dependencies: [
                "PodcastFeedVaporRedis",
                "PodcastFeedVapor",
                .product(name: "VaporTesting", package: "vapor")
            ]
        ),
        // Queues tests
        .testTarget(
            name: "PodcastFeedVaporQueuesTests",
            dependencies: [
                "PodcastFeedVaporQueues",
                "PodcastFeedVapor",
                .product(name: "Queues", package: "queues"),
                .product(name: "VaporTesting", package: "vapor")
            ]
        )
    ]
)
