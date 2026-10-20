// swift-tools-version: 6.4
import PackageDescription

// Phase 1 only: no implementation has migrated into this package yet.
let package = Package(
    name: "SBJStructuredEditor",
    platforms: [.iOS(.v17), .watchOS(.v10), .visionOS(.v1), .tvOS(.v17)],
    products: [.library(name: "SBJStructuredEditor", targets: ["SBJStructuredEditor"])],
    dependencies: [.package(path: "../SBJDataDefinition"), .package(path: "../SBJUIVocabulary")],
    targets: [
        .target(name: "SBJStructuredEditor", dependencies: [.product(name: "SBJDataDefinition", package: "SBJDataDefinition"), .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),]),
        .testTarget(name: "SBJStructuredEditorTests", dependencies: ["SBJStructuredEditor"]),
    ]
)
