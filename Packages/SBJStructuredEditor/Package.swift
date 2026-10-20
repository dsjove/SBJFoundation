// swift-tools-version: 6.4
import PackageDescription

// Public module boundary for the structured editor.
let package = Package(
    name: "SBJStructuredEditor",
    platforms: [.iOS(.v17), .watchOS(.v10), .visionOS(.v1), .tvOS(.v17)],
    products: [.library(name: "SBJStructuredEditor", targets: ["SBJStructuredEditor"])],
    dependencies: [.package(path: "../SBJDataDefinition"), .package(path: "../SBJUIVocabulary"), .package(path: "../SBJLocalization"), .package(path: "../SBJUnits")],
    targets: [
        .target(name: "SBJStructuredEditor", dependencies: [.product(name: "SBJDataDefinition", package: "SBJDataDefinition"), .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"), .product(name: "SBJLocalization", package: "SBJLocalization"), .product(name: "SBJUnits", package: "SBJUnits"),]),
    ]
)
