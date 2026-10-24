// swift-tools-version: 6.4
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SBJStructuredEditor",
    platforms: [
		.iOS(.v17),
		.watchOS(.v10),
		.visionOS(.v1),
		.tvOS(.v17)
	],
    products: [.library(name: "SBJStructuredEditor", targets: ["SBJStructuredEditor"])],
    dependencies: [
        .package(path: "../SBJDataDefinition"),
        .package(path: "../SBJUIVocabulary"),
        .package(path: "../SBJLocalization"),
        .package(path: "../SBJUnits"),
        .package(path: "../SBJFileResources"),
        .package(path: "../SBJHelp"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "604.0.0-prerelease-2026-06-05"),
    ],
    targets: [
        .macro(name: "SBJStructuredEditorMacros", dependencies: [
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SBJStructureMacroSupport", package: "SBJDataDefinition"),
        ]),
        .target(name: "SBJStructuredEditor", dependencies: [
            "SBJStructuredEditorMacros",
            .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
            .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
            .product(name: "SBJLocalization", package: "SBJLocalization"),
            .product(name: "SBJUnits", package: "SBJUnits"),
            .product(name: "SBJFileResources", package: "SBJFileResources"),
            .product(name: "SBJHelp", package: "SBJHelp"),
        ],
            resources: [
                .process("Resources"),
            ]),
        .testTarget(name: "SBJStructuredEditorTests", dependencies: [
            "SBJStructuredEditor", "SBJStructuredEditorMacros",
            .product(name: "SBJDataDefinition", package: "SBJDataDefinition"),
            .product(name: "SBJLocalization", package: "SBJLocalization"),
            .product(name: "SBJUIVocabulary", package: "SBJUIVocabulary"),
            .product(name: "SBJUnits", package: "SBJUnits"),
            .product(name: "SBJFileResources", package: "SBJFileResources"),
            .product(name: "SBJHelp", package: "SBJHelp"),
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        ]),
    ]
)
