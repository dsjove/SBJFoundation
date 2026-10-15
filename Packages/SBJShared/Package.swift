// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "SBJShared",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "SBJShared", targets: ["SBJShared"]),
    ],
    targets: [
        .target(
            name: "SBJShared",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]
        ),
        .testTarget(name: "SBJSharedTests", dependencies: ["SBJShared"]),
    ]
)
