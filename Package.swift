// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "PromptPanel",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "1.10.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.1"),
    ],
    targets: [
        .executableTarget(
            name: "PromptPanel",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/PromptPanel",
            exclude: [
                "Resources/Info.plist",
                "Resources/PromptPanel.entitlements",
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "PromptPanelTests",
            dependencies: [
                "PromptPanel",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Tests/PromptPanelTests"
        ),
    ]
)
