// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJDocuments",
    platforms: [
		.iOS(.v17),
		.watchOS(.v10),
		.visionOS(.v1),
		.tvOS(.v17)
	],
    products: [.library(name: "SBJDocuments", targets: ["SBJDocuments"])],
    dependencies: [
		.package(path: "../SBJLocalization"),
		.package(path: "../SBJFileResources")
	],
    targets: [
        .target(name: "SBJDocuments", dependencies: [
            .product(name: "SBJLocalization", package: "SBJLocalization"), .product(name: "SBJFileResources", package: "SBJFileResources")
        ]),
        .testTarget(name: "SBJDocumentsTests", dependencies: [
                "SBJDocuments",
                .product(name: "SBJFileResources", package: "SBJFileResources"),
            ])
    ]
)
