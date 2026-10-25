// swift-tools-version: 6.4
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SBJDataDefinition",
    platforms: [
		.iOS(.v17),
		.watchOS(.v10),
		.visionOS(.v1),
		.tvOS(.v17)
	],
    products: [
        .library(name: "SBJDataDefinition", targets: ["SBJDataDefinition"]),
        .library(name: "SBJStructureMacroSupport", targets: ["SBJStructureMacroSupport"]),
    ],
    dependencies: [
        .package(path: "../SBJLocalization"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "604.0.0-prerelease-2026-06-05"),
    ],
    targets: [
        .target(name: "SBJStructureMacroSupport", dependencies: [
            .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        ]),
        .macro(name: "SBJDataDefinitionMacros", dependencies: [
            "SBJStructureMacroSupport",
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        ]),
        .target(
            name: "SBJDataDefinition",
            dependencies: [
				.product(name: "SBJLocalization", package: "SBJLocalization"),
				"SBJDataDefinitionMacros"
			]
        ),
        .testTarget(
            name: "SBJDataDefinitionTests",
            dependencies: ["SBJDataDefinition", "SBJDataDefinitionMacros", "SBJStructureMacroSupport", .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")]
        ),
    ]
)
