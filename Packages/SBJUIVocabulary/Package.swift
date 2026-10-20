// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJUIVocabulary",
    platforms: [.iOS(.v17), .watchOS(.v10), .visionOS(.v1), .tvOS(.v17)],
    products: [.library(name: "SBJUIVocabulary", targets: ["SBJUIVocabulary"])],
    dependencies: [
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJDataDefinition"),
    ],
    targets: [
        .target(
            name: "SBJUIVocabulary",
            dependencies: [
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
            ]
        ),
        .testTarget(name: "SBJUIVocabularyTests", dependencies: ["SBJUIVocabulary"]),
    ]
)
