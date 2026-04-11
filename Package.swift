// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonTCALibraries",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
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

        // MARK: Helpers
        .library(name: "CombineHelpers", targets: ["CombineHelpers"]),

        // MARK: - Clients
        .library(name: "InfoPlist", targets: ["InfoPlist"]),
        .library(name: "IDFAClient", targets: ["IDFAClient"]),
        .library(name: "UIDeviceClient", targets: ["UIDeviceClient"]),
        .library(name: "KeychainClient", targets: ["KeychainClient"]),
        .library(name: "PathMonitorClient", targets: ["PathMonitorClient"]),
        .library(name: "CoreLocationClient", targets: ["CoreLocationClient"]),
        .library(name: "FoundationExtension", targets: ["FoundationExtension"]),
        .library(name: "UIApplicationClient", targets: ["UIApplicationClient"]),
        .library(name: "RemoteNotificationsClient", targets: ["RemoteNotificationsClient"]),
        .library(name: "AppPromo", targets: ["AppPromo"]),

        // MARK: - Offer Redeem
        .library(name: "OfferRedeemClient", targets: ["OfferRedeemClient"]),
        .library(name: "OfferRedeemFeature", targets: ["OfferRedeemFeature"]),
    ],

    dependencies: [
      .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
      .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.1.0"),
      .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.1.5"),
      .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.3"),
      .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.25.0"),
    ],

    targets: [
        .target(
            name: "CommonTCALibraries",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "Build", "InfoPlist", "FoundationExtension", "UIDeviceClient",
                "ComposableUserNotifications", "ComposableStoreKit", "UIApplicationClient",
                "SwiftUIHelpers", "KeychainClient", "IDFAClient", "ImagePicker",
                "SwiftUIExtension", "PathMonitorClient", "NotificationHelpers",
                "RemoteNotificationsClient", "CoreLocationClient", "LoggerKit",
            ]
        ),

        .target(
            name: "Build",
            dependencies: [
                .product(name: "Tagged", package: "swift-tagged"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies")
            ]
        ),

        .target(
            name: "IDFAClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
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
            name: "ComposableUserNotifications",
            dependencies: [
              .product(name: "Dependencies", package: "swift-dependencies"),
              .product(name: "DependenciesMacros", package: "swift-dependencies"),
              .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
              .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),

        .target(
            name: "ComposableStoreKit",
            dependencies: [
              .product(name: "CasePaths", package: "swift-case-paths"),
              .product(name: "Dependencies", package: "swift-dependencies"),
              .product(name: "DependenciesMacros", package: "swift-dependencies"),
              .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
              "InfoPlist"
            ]
        ),

        .target(
            name: "UIApplicationClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),

        .target(
            name: "KeychainClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                "FoundationExtension"
            ]
        ),

        .target(
            name: "PathMonitorClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
                "FoundationExtension"
            ]
        ),

        .target(
            name: "RemoteNotificationsClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
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
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]
        ),

        .target(
            name: "UIDeviceClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies")
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
        .target(name: "LoggerKit"),
        .target(name: "CombineHelpers"),

        .target(name: "AppPromo"),

        // MARK: - Offer Redeem
        .target(
            name: "OfferRedeemClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "OfferRedeemFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "OfferRedeemClient",
            ]
        ),
        .testTarget(
            name: "OfferRedeemFeatureTests",
            dependencies: [
                "OfferRedeemFeature",
                "OfferRedeemClient",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

    ],
    swiftLanguageModes: [.v5]
)
