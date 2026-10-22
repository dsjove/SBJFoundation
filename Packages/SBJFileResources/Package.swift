// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJFileResources",
    platforms: [
		.iOS(.v17),
		.watchOS(.v10),
		.visionOS(.v1),
		.tvOS(.v17)
	],
    products: [.library(name: "SBJFileResources", targets: ["SBJFileResources"])],
    targets: [
        .target(name: "SBJFileResources"),
        .testTarget(name: "SBJFileResourcesTests", dependencies: ["SBJFileResources"])
    ]
)
