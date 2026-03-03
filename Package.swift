// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalNotificationKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "LocalNotificationKit",
            targets: ["LocalNotificationKit"]
        ),
        .library(
            name: "LocalNotificationKitDebugUI",
            targets: ["LocalNotificationKitDebugUI"]
        )
    ],
    targets: [
        .target(
            name: "LocalNotificationKit",
            path: "Sources/LocalNotificationKit",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "LocalNotificationKitDebugUI",
            dependencies: ["LocalNotificationKit"],
            path: "Sources/LocalNotificationKitDebugUI",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "LocalNotificationKitTests",
            dependencies: ["LocalNotificationKit"],
            path: "Tests/LocalNotificationKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
