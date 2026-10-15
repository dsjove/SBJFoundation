// swift-tools-version: 6.4
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SBJSubjectEditor",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [.library(name: "SBJSubjectEditor", targets: ["SBJSubjectEditor"])],
    dependencies: [
        .package(path: "../SBJShared"),
        .package(path: "../SBJSubject"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "604.0.0-prerelease-2026-06-05"),
    ],
    targets: [
        .target(name: "SBJSubjectEditor", dependencies: [.product(name: "SBJShared", package: "SBJShared"), .product(name: "SBJSubject", package: "SBJSubject")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ]
        ),
        .macro(name: "SBJSubjectEditorMacros", dependencies: [
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        ]),
    ]
)
