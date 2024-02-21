// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonTCALibraries",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],

    products: [
        .library(name: "Build", targets: ["Build"]),
        .library(name: "ImagePicker", targets: ["ImagePicker"]),
        .library(name: "SwiftUIHelpers", targets: ["SwiftUIHelpers"]),
        .library(name: "SwiftUIExtension", targets: ["SwiftUIExtension"]),
        .library(name: "CommonTCALibraries", targets: ["CommonTCALibraries"]),
        .library(name: "ComposableStoreKit", targets: ["ComposableStoreKit"]),
        .library(name: "NotificationHelpers", targets: ["NotificationHelpers"]),
        .library(name: "ComposableUserNotifications", targets: ["ComposableUserNotifications"]),

        // MARK: - Logger
        .library(name: "LoggerKit", targets: ["LoggerKit"]),

        // MARK: - Clients
        .library(name: "InfoPlist", targets: ["InfoPlist"]),
        .library(name: "IDFAClient", targets: ["IDFAClient"]),
        .library(name: "KeychainClient", targets: ["KeychainClient"]),
        .library(name: "PathMonitorClient", targets: ["PathMonitorClient"]),
        .library(name: "UserDefaultsClient", targets: ["UserDefaultsClient"]),
        .library(name: "CoreLocationClient", targets: ["CoreLocationClient"]),
        .library(name: "FoundationExtension", targets: ["FoundationExtension"]),
        .library(name: "UIApplicationClient", targets: ["UIApplicationClient"]),
        .library(name: "RemoteNotificationsClient", targets: ["RemoteNotificationsClient"]),
    ],

    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.1.5"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.2"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.6.0"),
        .package(url: "https://github.com/klundberg/composable-core-location.git", branch: "combine-only"),
    ],

    targets: [
        .target(
            name: "CommonTCALibraries",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "Build", "UserDefaultsClient", "InfoPlist", "FoundationExtension",
                "ComposableUserNotifications", "ComposableStoreKit", "UIApplicationClient",
                "SwiftUIHelpers", "KeychainClient", "IDFAClient",
                "SwiftUIExtension", "PathMonitorClient", "NotificationHelpers",
                "RemoteNotificationsClient", "CoreLocationClient", "LoggerKit",
                "ImagePicker"
            ]
        ),

        .target(
            name: "Build",
            dependencies: [
                .product(name: "Tagged", package: "swift-tagged"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]
        ),

        .target(
            name: "IDFAClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
                "FoundationExtension"
            ]
        ),

        .target(
          name: "ImagePicker",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
          ]
        ),

        .target(
            name: "UserDefaultsClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay")
            ]
        ),

        .target(
            name: "ComposableUserNotifications",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]
        ),

        .target(
            name: "ComposableStoreKit",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
                "UserDefaultsClient", "InfoPlist"
            ]
        ),

        .target(
            name: "UIApplicationClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]
        ),

        .target(
            name: "KeychainClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                "FoundationExtension"
            ]
        ),

        .target(
            name: "PathMonitorClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
                "FoundationExtension"
            ]
        ),

        .target(
            name: "RemoteNotificationsClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay")
            ]
        ),

        .target(
          name: "NotificationHelpers",
          dependencies: [
            "ComposableUserNotifications", "RemoteNotificationsClient"
          ]
        ),

        .target(
            name: "CoreLocationClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]
        ),
        
        .target(name: "InfoPlist", resources: [.process("Resources/")]),
        .target(
            name: "FoundationExtension",
                dependencies: [
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
                ]
        ),
        .target(name: "SwiftUIHelpers", dependencies: ["SwiftUIExtension"]),
        .target(name: "SwiftUIExtension"),
        .target(name: "LoggerKit")

    ]
)
