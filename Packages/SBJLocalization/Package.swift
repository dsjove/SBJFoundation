// swift-tools-version: 6.2

import PackageDescription

// Independent localization, text formatting, accessibility and symbology module.
let package = Package(
    name: "SBJLocalization",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "SBJLocalization", targets: ["SBJLocalization"]),
    ],
    targets: [
        .target(name: "SBJLocalization"),
        .testTarget(name: "SBJLocalizationTests", dependencies: ["SBJLocalization"]),
    ]
)
