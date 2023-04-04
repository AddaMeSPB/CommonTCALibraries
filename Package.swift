// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonTCALibraries",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "CommonTCALibraries", targets: ["CommonTCALibraries"]),
        .library(name: "Analytics", targets: ["Analytics"]),
        .library(name: "Build", targets: ["Build"]),
        .library(name: "ComposableStoreKit", targets: ["ComposableStoreKit"]),
        .library(name: "ComposableUserNotifications", targets: ["ComposableUserNotifications"]),
        .library(name: "TCAHelpers", targets: ["TCAHelpers"]),
        .library(name: "SwiftUIHelpers", targets: ["SwiftUIHelpers"]),
        .library(name: "SwiftUIExtension", targets: ["SwiftUIExtension"]),
        .library(name: "NotificationHelpers", targets: ["NotificationHelpers"]),


        // MARK: - Clients
        .library(name: "UserDefaultsClient", targets: ["UserDefaultsClient"]),
        .library(name: "InfoPlist", targets: ["InfoPlist"]),
        .library(name: "FoundationExtension", targets: ["FoundationExtension"]),
        .library(name: "UIApplicationClient", targets: ["UIApplicationClient"]),
        .library(name: "KeychainClient", targets: ["KeychainClient"]),
        .library(name: "RemoteNotificationsClient", targets: ["RemoteNotificationsClient"]),
        .library(name: "PathMonitorClient", targets: ["PathMonitorClient"]),
        .library(name: "IDFAClient", targets: ["IDFAClient"]),
        .library(name: "CoreLocationClient", targets: ["CoreLocationClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.53.2"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.6.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "0.1.0")
    ],
    targets: [

        .target(
            name: "CommonTCALibraries",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "Build", "UserDefaultsClient", "InfoPlist", "FoundationExtension",
                "ComposableUserNotifications", "ComposableStoreKit", "UIApplicationClient",
                "TCAHelpers", "SwiftUIHelpers", "KeychainClient", "IDFAClient",
                 "Analytics", "SwiftUIExtension", "PathMonitorClient", "NotificationHelpers",
                "RemoteNotificationsClient", "CoreLocationClient"
            ]),

        .target(
            name: "Build",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Tagged", package: "swift-tagged"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]),

        .target(
            name: "IDFAClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
                "FoundationExtension"
            ]),

        .target(
            name: "UserDefaultsClient",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]),

        .target(
            name: "ComposableUserNotifications",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]),

        .target(
            name: "ComposableStoreKit",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
                "UserDefaultsClient", "InfoPlist"
            ]),

        .target(
            name: "UIApplicationClient",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]),

        .target(
            name: "TCAHelpers",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]),

        .target(
            name: "KeychainClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                "FoundationExtension"
            ]),

        .target(
            name: "PathMonitorClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                "FoundationExtension"
            ]),

        .target(
            name: "RemoteNotificationsClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]),

        .target(
          name: "NotificationHelpers",
          dependencies: [
            "ComposableUserNotifications",
            "RemoteNotificationsClient",
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
          ]),

        .target(
            name: "CoreLocationClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]
        ),
        
        .target(name: "InfoPlist", resources: [.process("Resources/")]),
        .target(name: "FoundationExtension"),
        .target(name: "SwiftUIHelpers", dependencies: ["SwiftUIExtension"]),
        .target(name: "SwiftUIExtension"),
        .target(name: "Analytics"),

    ]
)
