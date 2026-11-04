// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJImaging",
    platforms: [
        .macOS(.v14), .iOS(.v17), .watchOS(.v10), .visionOS(.v1), .tvOS(.v17),
    ],
    products: [.library(name: "SBJImaging", targets: ["SBJImaging"])],
    dependencies: [
        .package(path: "../SBJCamera"),
        .package(path: "../SBJLocation"),
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJDataDefinition"),
        .package(path: "../SBJDocuments"),
        .package(path: "../SBJUIVocabulary"),
        .package(path: "../SBJHelp"),
        .package(path: "../SBJSharing"),
    ],
    targets: [
        .target(
            name: "SBJImaging",
            dependencies: [
                .product(name: "SBJCamera", package: "SBJCamera"),
                .product(name: "SBJLocation", package: "SBJLocation"),
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJDocuments", package: "SBJDocuments"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJHelp", package: "SBJHelp"),
                .product(name: "SBJSharing", package: "SBJSharing"),
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
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]
        ),
    ]
)
