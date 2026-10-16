// swift-tools-version: 6.4

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SBJFoundation",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "SBJFoundation",
            targets: ["SBJFoundation"]
        ),
    ],
    dependencies: [
        .package(path: "Packages/SBJLocalization"),
        .package(path: "Packages/SBJCamera"),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "604.0.0-prerelease-2026-06-05"
        ),
    ],
    targets: [
        .macro(
            name: "SBJFoundationMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "SBJFoundation",
            dependencies: [
                "SBJFoundationMacros",
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJCamera", package: "SBJCamera"),
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ],
        ),
        .testTarget(
            name: "SBJFoundationTests",
            dependencies: [
                "SBJFoundation",
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJCamera", package: "SBJCamera"),
                "SBJFoundationMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ],
        ),
    ]
)
