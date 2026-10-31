// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "SBJFoundation",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "SBJFoundation",
            targets: ["SBJFoundation"]
        ),
    ],
    dependencies: [
        .package(path: "Packages/SBJLocalization"),
        .package(path: "Packages/SBJCamera"),
        .package(path: "Packages/SBJLocation"),
        .package(path: "Packages/SBJFileResources"),
        .package(path: "Packages/SBJDataDefinition"),
        .package(path: "Packages/SBJDocuments"),
        .package(path: "Packages/SBJUIVocabulary"),
        .package(path: "Packages/SBJLayout"),
        .package(path: "Packages/SBJImage"),
        .package(path: "Packages/SBJDataDefinitionReport"),
        .package(path: "Packages/SBJHelp"),
        .package(path: "Packages/SBJSharing"),
        .package(path: "Packages/SBJTags"),
        .package(path: "Packages/SBJStructuredEditor"),
    ],
    targets: [
        .target(
            name: "SBJFoundation",
            dependencies: [
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJCamera", package: "SBJCamera"),
                .product(name: "SBJLocation", package: "SBJLocation"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJDocuments", package: "SBJDocuments"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJLayout", package: "SBJLayout"),
                .product(name: "SBJImage", package: "SBJImage"),
                .product(name: "SBJDataDefinitionReport", package: "SBJDataDefinitionReport"),
                .product(name: "SBJHelp", package: "SBJHelp"),
                .product(name: "SBJSharing", package: "SBJSharing"),
                .product(name: "SBJTags", package: "SBJTags"),
                .product(name: "SBJStructuredEditor", package: "SBJStructuredEditor"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ],
        ),
        .testTarget(
            name: "SBJFoundationTests",
            dependencies: [
                "SBJFoundation",
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJLayout", package: "SBJLayout"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ],
        ),
    ]
)
