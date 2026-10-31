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
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJDataDefinition"),
        .package(path: "../SBJUIVocabulary"),
        .package(path: "../SBJLayout"),
        .package(path: "../SBJHelp"),
        .package(path: "../SBJDataDefinitionReport"),
    ],
    targets: [
        .target(name: "SBJStructuredEditor", dependencies: [
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJLayout", package: "SBJLayout"),
                .product(name: "SBJHelp", package: "SBJHelp"),
                .product(name: "SBJDataDefinitionReport", package: "SBJDataDefinitionReport"),
            ],
            resources: [
                .process("Resources"),
            ]),
        .testTarget(name: "SBJStructuredEditorTests", dependencies: [
                "SBJStructuredEditor",
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
            ]),
    ]
)
