// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJDataDefinitionReport",
    platforms: [.iOS(.v17), .watchOS(.v10), .visionOS(.v1), .tvOS(.v17)],
    products: [.library(name: "SBJDataDefinitionReport", targets: ["SBJDataDefinitionReport"])],
    dependencies: [
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJDataDefinition"),
        .package(path: "../SBJUIVocabulary"),
        .package(path: "../SBJLayout"),
        .package(path: "../SBJSharing"),
    ],
    targets: [
        .target(name: "SBJDataDefinitionReport", dependencies: [
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJLayout", package: "SBJLayout"),
                .product(name: "SBJSharing", package: "SBJSharing"),
            ])
    ]
)
