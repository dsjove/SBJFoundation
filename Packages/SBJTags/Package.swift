// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJTags",
    platforms: [
        .iOS(.v17), .watchOS(.v10), .visionOS(.v1), .tvOS(.v17),
    ],
    products: [.library(name: "SBJTags", targets: ["SBJTags"])],
    dependencies: [
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJDocuments"),
        .package(path: "../SBJUIVocabulary"),
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJHelp"),
        .package(path: "../SBJDataDefinition"),
        .package(path: "../SBJLayout"),
    ],
    targets: [
        .target(
            name: "SBJTags",
            dependencies: [
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJDocuments", package: "SBJDocuments"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJHelp", package: "SBJHelp"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJLayout", package: "SBJLayout"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]
        ),
        .testTarget(
            name: "SBJTagsTests",
            dependencies: [
                "SBJTags",
                .product(name: "SBJLayout", package: "SBJLayout"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]
        ),
    ]
)
