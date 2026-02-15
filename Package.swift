// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "podcast-feed-maker-vapor",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PodcastFeedVapor", targets: ["PodcastFeedVapor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/atelier-socle/podcast-feed-maker.git", from: "0.2.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.121.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "PodcastFeedVapor",
            dependencies: [
                .product(name: "PodcastFeedMaker", package: "podcast-feed-maker"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
            ]
        ),
        .testTarget(
            name: "PodcastFeedVaporTests",
            dependencies: [
                "PodcastFeedVapor",
                .product(name: "VaporTesting", package: "vapor"),
            ]
        ),
    ]
)
