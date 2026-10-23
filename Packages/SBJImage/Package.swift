// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJImage",
    platforms: [
        .iOS(.v17), .watchOS(.v10), .visionOS(.v1), .tvOS(.v17),
    ],
    products: [.library(name: "SBJImage", targets: ["SBJImage"])],
    dependencies: [
        .package(path: "../SBJCamera"),
        .package(path: "../SBJDataDefinition"),
        .package(path: "../SBJDocuments"),
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJHelp"),
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJLocation"),
        .package(path: "../SBJSharing"),
        .package(path: "../SBJUIVocabulary"),
    ],
    targets: [
        .target(
            name: "SBJImage",
            dependencies: [
                .product(name: "SBJCamera", package: "SBJCamera"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJDocuments", package: "SBJDocuments"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJHelp", package: "SBJHelp"),
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJLocation", package: "SBJLocation"),
                .product(name: "SBJSharing", package: "SBJSharing"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]
        ),
        .testTarget(
            name: "SBJImageTests",
            dependencies: [
                "SBJImage",
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
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
