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
        .package(path: "Packages/SBJLocation"),
        .package(path: "Packages/SBJSharing"),
        .package(path: "Packages/SBJLocalization"),
        .package(path: "Packages/SBJDataDefinition"),
        .package(path: "Packages/SBJStructuredEditor"),
        .package(path: "Packages/SBJUnits"),
        .package(path: "Packages/SBJUIVocabulary"),
        .package(path: "Packages/SBJCamera"),
        .package(path: "Packages/SBJDocuments"),
        .package(path: "Packages/SBJFileResources"),
        .package(path: "Packages/SBJHelp"),
        .package(path: "Packages/SBJLayout"),
    ],
    targets: [
        .target(
            name: "SBJFoundation",
            dependencies: [
                .product(name: "SBJLocation", package: "SBJLocation"),
                .product(name: "SBJSharing", package: "SBJSharing"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJStructuredEditor", package: "SBJStructuredEditor"),
                .product(name: "SBJUnits", package: "SBJUnits"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJCamera", package: "SBJCamera"),
                .product(name: "SBJDocuments", package: "SBJDocuments"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJHelp", package: "SBJHelp"),
                .product(name: "SBJLayout", package: "SBJLayout"),
            ],
            resources: [
                .process("Resources"),
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
                .product(name: "SBJLocation", package: "SBJLocation"),
                .product(name: "SBJSharing", package: "SBJSharing"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJStructuredEditor", package: "SBJStructuredEditor"),
                .product(name: "SBJUnits", package: "SBJUnits"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJCamera", package: "SBJCamera"),
                .product(name: "SBJDocuments", package: "SBJDocuments"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJHelp", package: "SBJHelp"),
                .product(name: "SBJLayout", package: "SBJLayout"),
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ],
        ),
    ]
)
