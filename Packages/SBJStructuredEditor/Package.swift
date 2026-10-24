// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJStructuredEditor",
    platforms: [
		.iOS(.v17),
		.watchOS(.v10),
		.visionOS(.v1),
		.tvOS(.v17)
	],
    products: [.library(name: "SBJStructuredEditor", targets: ["SBJStructuredEditor"])],
    dependencies: [
        .package(path: "../SBJDataDefinition"),
        .package(path: "../SBJUIVocabulary"),
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJHelp"),
    ],
    targets: [
        .target(name: "SBJStructuredEditor", dependencies: [
            .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
            .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
            .product(name: "SBJLocalization", package: "SBJLocalization"),
            .product(name: "SBJFileResources", package: "SBJFileResources"),
            .product(name: "SBJHelp", package: "SBJHelp"),
        ],
            resources: [
                .process("Resources"),
            ]),
        .testTarget(name: "SBJStructuredEditorTests", dependencies: [
            "SBJStructuredEditor",
            .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
            .product(name: "SBJLocalization", package: "SBJLocalization"),
            .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
            .product(name: "SBJFileResources", package: "SBJFileResources"),
            .product(name: "SBJHelp", package: "SBJHelp"),
        ]),
    ]
)
