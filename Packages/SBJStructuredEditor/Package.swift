// swift-tools-version: 6.4
import PackageDescription

// Phase 1 only: no implementation has migrated into this package yet.
let package = Package(
    name: "SBJStructuredEditor",
    platforms: [.iOS(.v17), .watchOS(.v10), .visionOS(.v1), .tvOS(.v17)],
    products: [.library(name: "SBJStructuredEditor", targets: ["SBJStructuredEditor"])],
    dependencies: [.package(path: "../SBJDataDefinition")],
    targets: [
        .target(name: "SBJStructuredEditor", dependencies: [.product(name: "SBJDataDefinition", package: "SBJDataDefinition")]),
        .testTarget(name: "SBJStructuredEditorTests", dependencies: ["SBJStructuredEditor"]),
    ]
)
