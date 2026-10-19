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
        .package(path: "Packages/SBJDataDefinition"),
        .package(path: "Packages/SBJStructuredEditor"),
        .package(path: "Packages/SBJCamera"),
        .package(path: "Packages/SBJDocuments"),
        .package(path: "Packages/SBJFileResources"),
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
                .product(name: "SBJStructureMacroSupport", package: "SBJDataDefinition"),
            ]
        ),
        .target(
            name: "SBJFoundation",
            dependencies: [
                "SBJFoundationMacros",
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJStructuredEditor", package: "SBJStructuredEditor"),
                .product(name: "SBJLocalization", package: "SBJLocalization"),
                .product(name: "SBJCamera", package: "SBJCamera"),
                .product(name: "SBJDocuments", package: "SBJDocuments"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
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
                .product(name: "SBJDocuments", package: "SBJDocuments"),
                .product(name: "SBJFileResources", package: "SBJFileResources"),
                "SBJFoundationMacros",
                .product(name: "SBJStructureMacroSupport", package: "SBJDataDefinition"),
                .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
                .product(name: "SBJStructuredEditor", package: "SBJStructuredEditor"),
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
