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
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJFileResources"),
    ],
    targets: [
        .target(name: "SBJHelp", dependencies: [
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
            ]),
        .testTarget(name: "SBJHelpTests", dependencies: [
                "SBJHelp",
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
            ], resources: [.process("Resources")]),
    ]
)
