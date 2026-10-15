// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJDocuments",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "SBJDocuments", targets: ["SBJDocuments"]),
    ],
    dependencies: [
        .package(path: "../SBJShared"),
    ],
    targets: [
        .target(
            name: "SBJDocuments",
            dependencies: [
                .product(name: "SBJShared", package: "SBJShared"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]
        ),
    ]
)
