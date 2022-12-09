// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonTCALibraries",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "CommonTCALibraries", targets: ["CommonTCALibraries"]),
        .library(name: "Analytics", targets: ["Analytics"]),
        .library(name: "Build", targets: ["Build"]),
        .library(name: "ComposableStoreKit", targets: ["ComposableStoreKit"]),
        .library(name: "ComposableUserNotifications", targets: ["ComposableUserNotifications"]),
        .library(name: "TCAHelpers", targets: ["TCAHelpers"]),
        .library(name: "SwiftUIHelpers", targets: ["SwiftUIHelpers"]),
        .library(name: "Models", targets: ["Models"]),

        // MARK: - clients
        .library(name: "UserDefaultsClient", targets: ["UserDefaultsClient"]),
        .library(name: "InfoPlist", targets: ["InfoPlist"]),
        .library(name: "FoundationExtension", targets: ["FoundationExtension"]),
        .library(name: "UIApplicationClient", targets: ["UIApplicationClient"]),
        .library(name: "KeychainClient", targets: ["KeychainClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.47.2"),
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
                "TCAHelpers", "SwiftUIHelpers", "KeychainClient",
                "Models", "Analytics"
            ]),

        .target(
            name: "Build",
            dependencies: [
                .product(name: "Dependencies", package: "swift-composable-architecture"),
                .product(name: "Tagged", package: "swift-tagged"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
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
                .product(name: "Dependencies", package: "swift-composable-architecture"),
            ]),

        .target(name: "InfoPlist", resources: [.process("Resources/")]),
        .target(name: "FoundationExtension"),
        .target(name: "SwiftUIHelpers"),
        .target(name: "Models"),
        .target(name: "Analytics"),

    ]
)
