// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJSharing",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [.library(name: "SBJSharing", targets: ["SBJSharing"])],
    dependencies: [
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJUIVocabulary"),
    ],
    targets: [
        .target(
            name: "SBJSharing",
            dependencies: [
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]
        ),
    ]
)
