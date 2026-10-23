// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJUIVocabulary",
    platforms: [
		.iOS(.v17),
		.watchOS(.v10),
		.visionOS(.v1),
		.tvOS(.v17)
	],
    products: [.library(name: "SBJUIVocabulary", targets: ["SBJUIVocabulary"])],
    dependencies: [
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJDataDefinition"),
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJUnits"),
    ],
    targets: [
        .target(
            name: "SBJUIVocabulary",
            dependencies: [
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJUnits", package: "SBJUnits"),
            ],
            resources: [.process("Resources")],
        ),
        .testTarget(name: "SBJUIVocabularyTests", dependencies: ["SBJUIVocabulary"]),
    ]
)
