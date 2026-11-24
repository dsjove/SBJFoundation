// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SBJCamera",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [.library(name: "SBJCamera", targets: ["SBJCamera"])],
    dependencies: [.package(path: "../SBJLocalization")],
    targets: [
        .target(name: "SBJCamera", dependencies: [.product(name: "SBJLocalization", package: "SBJLocalization")], swiftSettings: [
            .enableUpcomingFeature("ApproachableConcurrency"),
            .defaultIsolation(nil),
        ]),
        .testTarget(name: "SBJCameraTests", dependencies: [
                "SBJCamera",
            ]),
    ]
)
