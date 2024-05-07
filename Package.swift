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
        .library(name: "CommonTCALibraries", targets: ["CommonTCALibraries"]),
        .library(name: "Build", targets: ["Build"]),
        .library(name: "ComposableStoreKit", targets: ["ComposableStoreKit"]),
        .library(name: "ComposableUserNotifications", targets: ["ComposableUserNotifications"]),
        .library(name: "SwiftUIHelpers", targets: ["SwiftUIHelpers"]),
        .library(name: "SwiftUIExtension", targets: ["SwiftUIExtension"]),
        .library(name: "NotificationHelpers", targets: ["NotificationHelpers"]),
        .library(name: "iPhoneNumberKit", targets: ["iPhoneNumberKit"]),

        // MARK: - Logger
        .library(name: "LoggerKit", targets: ["LoggerKit"]),

        // MARK: - Clients
        .library(name: "UserDefaultsClient", targets: ["UserDefaultsClient"]),
        .library(name: "InfoPlist", targets: ["InfoPlist"]),
        .library(name: "FoundationExtension", targets: ["FoundationExtension"]),
        .library(name: "UIApplicationClient", targets: ["UIApplicationClient"]),
        .library(name: "KeychainClient", targets: ["KeychainClient"]),
        .library(name: "RemoteNotificationsClient", targets: ["RemoteNotificationsClient"]),
        .library(name: "PathMonitorClient", targets: ["PathMonitorClient"]),
        .library(name: "IDFAClient", targets: ["IDFAClient"]),
        .library(name: "CoreLocationClient", targets: ["CoreLocationClient"])
    ],

    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.4.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.6.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
        .package(url: "https://github.com/marmelroy/PhoneNumberKit", from: "3.7.0"),
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
                "iPhoneNumberKit"
            ]
        ),

        .target(
            name: "Build",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Tagged", package: "swift-tagged"),
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
        .target(name: "FoundationExtension"),
        .target(name: "SwiftUIHelpers", dependencies: ["SwiftUIExtension"]),
        .target(name: "SwiftUIExtension"),
        .target(name: "LoggerKit"),
        .target(
            name: "iPhoneNumberKit",
            dependencies: [
                .product(name: "PhoneNumberKit", package: "PhoneNumberKit")
            ]
        )
    ]
)
