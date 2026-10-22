// swift-tools-version: 6.4

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SBJLayout",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "SBJLayout",
            targets: ["SBJLayout"]
        ),
    ],
    dependencies: [
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJDataDefinition"),
        .package(path: "../SBJStructuredEditor"),
        .package(path: "../SBJUnits"),
    ],
    targets: [
        .target(
            name: "SBJLayout",
            dependencies: [
				.product(name: "SBJUnits", package: "SBJUnits"),
				.product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
				.product(name: "SBJStructuredEditor", package: "SBJStructuredEditor"),
				.product(name: "SBJLocalization", package: "SBJLocalization")],
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ],
        ),
        .testTarget(
            name: "SBJLayoutTests",
            dependencies: ["SBJLayout", .product(name: "SBJLocalization", package: "SBJLocalization")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ],
        ),
    ]
)
