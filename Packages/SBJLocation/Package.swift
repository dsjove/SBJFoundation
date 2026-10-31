// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJLocation",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [.library(name: "SBJLocation", targets: ["SBJLocation"])],
    dependencies: [
		.package(path: "../SBJLocalization")
    ],
    targets: [
        .target(
            name: "SBJLocation",
            dependencies: [
				.product(name: "SBJLocalization", package: "SBJLocalization")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]
        ),
        .testTarget(name: "SBJLocationTests", dependencies: [
                "SBJLocation",
            ]),
    ]
)
