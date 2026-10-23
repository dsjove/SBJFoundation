// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJHelp",
    platforms: [
		.iOS(.v17),
		.watchOS(.v10),
		.visionOS(.v1),
		.tvOS(.v17)
	],
    products: [.library(name: "SBJHelp", targets: ["SBJHelp"])],
    dependencies: [
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJLocalization"),
    ],
    targets: [
        .target(name: "SBJHelp", dependencies: [
            .product(name: "SBJFileResources", package: "SBJFileResources"),
            .product(name: "SBJLocalization", package: "SBJLocalization"),
        ]),
        .testTarget(name: "SBJHelpTests", dependencies: [
            "SBJHelp",
            .product(name: "SBJFileResources", package: "SBJFileResources"),
            .product(name: "SBJLocalization", package: "SBJLocalization"),
        ], resources: [.process("Resources")]),
    ]
)
