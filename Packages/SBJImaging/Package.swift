// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJImaging",
    platforms: [
        .macOS(.v14),
        .macCatalyst(.v17),
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [.library(name: "SBJImaging", targets: ["SBJImaging"])],
    dependencies: [
        .package(path: "../SBJCamera"),
        .package(path: "../SBJLocation"),
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJStructure"),
        .package(path: "../SBJDocuments"),
        .package(path: "../SBJUIVocabulary"),
        .package(path: "../SBJHelp"),
        .package(path: "../SBJTags"),
    ],
    targets: [
        .target(
            name: "SBJImaging",
            dependencies: [
                .product(name: "SBJCamera", package: "SBJCamera"),
                .product(name: "SBJLocation", package: "SBJLocation"),
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJStructure", package: "SBJStructure"),
                .product(name: "SBJDocuments", package: "SBJDocuments"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJHelp", package: "SBJHelp"),
                .product(name: "SBJTags", package: "SBJTags"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]
        ),
        .testTarget(
            name: "SBJImagingTests",
            dependencies: [
                "SBJImaging",
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJStructure", package: "SBJStructure"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJTags", package: "SBJTags"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]
        ),
    ]
)
