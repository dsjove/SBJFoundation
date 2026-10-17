// swift-tools-version: 6.4
import PackageDescription

// Phase 1 only: no implementation has migrated into this package yet.
let package = Package(
    name: "SBJDataDefinition",
    platforms: [.iOS(.v17), .watchOS(.v10), .visionOS(.v1), .tvOS(.v17)],
    products: [.library(name: "SBJDataDefinition", targets: ["SBJDataDefinition"])],
    targets: [
        .target(name: "SBJDataDefinition"),
        .testTarget(name: "SBJDataDefinitionTests", dependencies: ["SBJDataDefinition"]),
    ]
)
