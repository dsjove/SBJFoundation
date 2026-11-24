// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "SBJFoundation",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
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
        .package(path: "Packages/SBJStructure"),
        .package(path: "Packages/SBJStructuredAI"),
        .package(path: "Packages/SBJDocuments"),
        .package(path: "Packages/SBJHelp"),
        .package(path: "Packages/SBJUIVocabulary"),
        .package(path: "Packages/SBJLayout"),
        .package(path: "Packages/SBJStructuredReport"),
        .package(path: "Packages/SBJTags"),
        .package(path: "Packages/SBJStructuredEditor"),
        .package(path: "Packages/SBJImaging"),
    ],
    targets: [
        .target(
            name: "SBJFoundation",
            dependencies: [
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJCamera", package: "SBJCamera"),
                .product(name: "SBJLocation", package: "SBJLocation"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJStructure", package: "SBJStructure"),
                .product(name: "SBJStructuredAI", package: "SBJStructuredAI"),
                .product(name: "SBJDocuments", package: "SBJDocuments"),
                .product(name: "SBJHelp", package: "SBJHelp"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJLayout", package: "SBJLayout"),
                .product(name: "SBJStructuredReport", package: "SBJStructuredReport"),
                .product(name: "SBJTags", package: "SBJTags"),
                .product(name: "SBJStructuredEditor", package: "SBJStructuredEditor"),
                .product(name: "SBJImaging", package: "SBJImaging"),
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
