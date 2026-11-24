// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJUIVocabulary",
    platforms: [
		.iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
		.watchOS(.v10),
		.visionOS(.v1),
		.tvOS(.v17)
	],
    products: [.library(name: "SBJUIVocabulary", targets: ["SBJUIVocabulary"])],
    dependencies: [
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJStructure"),
    ],
    targets: [
        .target(
            name: "SBJUIVocabulary",
            dependencies: [
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                .product(name: "SBJStructure", package: "SBJStructure"),
            ],
            resources: [.process("Resources")],
        ),
        .testTarget(name: "SBJUIVocabularyTests", dependencies: [
                "SBJUIVocabulary",
            ]),
    ]
)
