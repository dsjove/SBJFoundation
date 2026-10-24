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
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJDataDefinition"),
        .package(path: "../SBJUIVocabulary"),
    ],
    targets: [
        .target(
            name: "SBJLayout",
            dependencies: [
				.product(name: "SBJLocalization", package: "SBJLocalization"),
				.product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
				.product(name: "SBJFileResources", package: "SBJFileResources"),
				.product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
			],
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ],
        ),
        .testTarget(
            name: "SBJLayoutTests",
            dependencies: [
				"SBJLayout",
				.product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition")
			],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ],
        ),
    ]
)
