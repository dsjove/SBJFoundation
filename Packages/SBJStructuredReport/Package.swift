// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJStructuredReport",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
	],
    products: [.library(name: "SBJStructuredReport", targets: ["SBJStructuredReport"])],
    dependencies: [
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJStructure"),
        .package(path: "../SBJUIVocabulary"),
        .package(path: "../SBJLayout"),
    ],
    targets: [
        .target(name: "SBJStructuredReport", dependencies: [
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJStructure", package: "SBJStructure"),
                .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
                .product(name: "SBJLayout", package: "SBJLayout"),
            ]),
        .testTarget(name: "SBJStructuredReportTests", dependencies: [
            "SBJStructuredReport",
            .product(name: "SBJStructure", package: "SBJStructure")
        ])
    ]
)
