// swift-tools-version: 6.4
import PackageDescription

// Scaffold only. Unit implementation remains in SBJFoundation.
let package = Package(
    name: "SBJUnits",
    platforms: [.iOS(.v17), .watchOS(.v10), .visionOS(.v1), .tvOS(.v17)],
    products: [.library(name: "SBJUnits", targets: ["SBJUnits"])],
    dependencies: [
        .package(path: "../SBJDataDefinition"),
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJUIVocabulary"),
        .package(path: "../SBJHelp"),
    ],
    targets: [
        .target(name: "SBJUnits", dependencies: [
            .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
            .product(name: "SBJLocalization", package: "SBJLocalization"),
            .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
            .product(name: "SBJHelp", package: "SBJHelp"),
        ]),
        .testTarget(name: "SBJUnitsTests", dependencies: ["SBJUnits"]),
    ]
)
