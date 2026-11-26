// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJStructuredAI",
    platforms: [
        .iOS(.v17), .macOS(.v14), .macCatalyst(.v17),
        .watchOS(.v10), .visionOS(.v1), .tvOS(.v17),
    ],
    products: [.library(name: "SBJStructuredAI", targets: ["SBJStructuredAI"])],
    dependencies: [
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJStructure"),
    ],
    targets: [
        .target(name: "SBJStructuredAI", dependencies: [
            .product(name: "SBJLocalization", package: "SBJLocalization"),
            .product(name: "SBJStructure", package: "SBJStructure"),
        ]),
        .testTarget(name: "SBJStructuredAITests", dependencies: ["SBJStructuredAI", "SBJLocalization", "SBJStructure"])
    ]
)
