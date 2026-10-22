// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJCamera",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [.library(name: "SBJCamera", targets: ["SBJCamera"])],
    targets: [
        .target(name: "SBJCamera", swiftSettings: [
            .enableUpcomingFeature("ApproachableConcurrency"),
            .defaultIsolation(nil),
        ]),
        .testTarget(name: "SBJCameraTests", dependencies: ["SBJCamera"]),
    ]
)
