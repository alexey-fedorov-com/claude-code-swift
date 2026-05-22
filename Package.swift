// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "SwiftCode",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "swiftcode", targets: ["SwiftCode"]),
        .library(name: "SwiftCodeCLI", targets: ["SwiftCodeCLI"]),
        .library(name: "SwiftCodeCore", targets: ["SwiftCodeCore"]),
        .library(name: "SwiftCodeAPI", targets: ["SwiftCodeAPI"]),
        .library(name: "SwiftCodeAgent", targets: ["SwiftCodeAgent"]),
        .library(name: "SwiftCodeTerminalUI", targets: ["SwiftCodeTerminalUI"]),
        .library(name: "SwiftCodeTools", targets: ["SwiftCodeTools"]),
        .library(name: "SwiftCodeCommands", targets: ["SwiftCodeCommands"]),
        .library(name: "SwiftCodeSettings", targets: ["SwiftCodeSettings"]),
        .library(name: "SwiftCodePermissions", targets: ["SwiftCodePermissions"]),
        .library(name: "SwiftCodeHooks", targets: ["SwiftCodeHooks"]),
        .library(name: "SwiftCodePlugins", targets: ["SwiftCodePlugins"]),
        .library(name: "SwiftCodeMCP", targets: ["SwiftCodeMCP"]),
        .library(name: "SwiftCodeLSP", targets: ["SwiftCodeLSP"]),
        .library(name: "SwiftCodeRemote", targets: ["SwiftCodeRemote"]),
        .library(name: "SwiftCodeVim", targets: ["SwiftCodeVim"]),
        .library(name: "SwiftCodeNative", targets: ["SwiftCodeNative"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.98.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.2"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.5.0")
    ],
    targets: [
        .executableTarget(
            name: "SwiftCode",
            dependencies: ["SwiftCodeCLI"]
        ),
        .target(
            name: "SwiftCodeCLI",
            dependencies: [
                "SwiftCodeCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(name: "SwiftCodeCore", dependencies: [.product(name: "Logging", package: "swift-log")]),
        .target(name: "SwiftCodeAPI", dependencies: ["SwiftCodeCore", .product(name: "AsyncHTTPClient", package: "async-http-client")]),
        .target(name: "SwiftCodeAgent", dependencies: ["SwiftCodeCore", "SwiftCodeAPI", "SwiftCodeNative"]),
        .target(name: "SwiftCodeTerminalUI", dependencies: ["SwiftCodeCore", .product(name: "NIOCore", package: "swift-nio")]),
        .target(name: "SwiftCodeTools", dependencies: ["SwiftCodeCore", "SwiftCodeAgent", "SwiftCodeTerminalUI"]),
        .target(name: "SwiftCodeCommands", dependencies: ["SwiftCodeCore", "SwiftCodeTools", "SwiftCodeTerminalUI"]),
        .target(name: "SwiftCodeSettings", dependencies: ["SwiftCodeCore"]),
        .target(name: "SwiftCodePermissions", dependencies: ["SwiftCodeCore", "SwiftCodeSettings"]),
        .target(name: "SwiftCodeHooks", dependencies: ["SwiftCodeCore", "SwiftCodeSettings"]),
        .target(name: "SwiftCodePlugins", dependencies: ["SwiftCodeCore", "SwiftCodeSettings", "SwiftCodeHooks"]),
        .target(name: "SwiftCodeMCP", dependencies: ["SwiftCodeCore", "SwiftCodeAPI", "SwiftCodePermissions", .product(name: "NIOCore", package: "swift-nio")]),
        .target(name: "SwiftCodeLSP", dependencies: ["SwiftCodeCore", .product(name: "NIOCore", package: "swift-nio")]),
        .target(name: "SwiftCodeRemote", dependencies: ["SwiftCodeCore", "SwiftCodeAPI", "SwiftCodeAgent", .product(name: "NIOCore", package: "swift-nio")]),
        .target(name: "SwiftCodeVim", dependencies: ["SwiftCodeCore"]),
        .target(name: "SwiftCodeNative", dependencies: ["SwiftCodeCore", .product(name: "Crypto", package: "swift-crypto")]),
        .testTarget(name: "SwiftCodeCLITests", dependencies: ["SwiftCodeCLI"]),
        .testTarget(name: "SwiftCodeCoreTests", dependencies: ["SwiftCodeCore"]),
        .testTarget(name: "SwiftCodeAPITests", dependencies: ["SwiftCodeAPI"]),
        .testTarget(name: "SwiftCodeAgentTests", dependencies: ["SwiftCodeAgent"]),
        .testTarget(name: "SwiftCodeTerminalUITests", dependencies: ["SwiftCodeTerminalUI"]),
        .testTarget(name: "SwiftCodeToolsTests", dependencies: ["SwiftCodeTools"]),
        .testTarget(name: "SwiftCodeCommandsTests", dependencies: ["SwiftCodeCommands"]),
        .testTarget(name: "SwiftCodeSettingsTests", dependencies: ["SwiftCodeSettings"]),
        .testTarget(name: "SwiftCodePermissionsTests", dependencies: ["SwiftCodePermissions"]),
        .testTarget(name: "SwiftCodeHooksTests", dependencies: ["SwiftCodeHooks"]),
        .testTarget(name: "SwiftCodePluginsTests", dependencies: ["SwiftCodePlugins"]),
        .testTarget(name: "SwiftCodeMCPTests", dependencies: ["SwiftCodeMCP"]),
        .testTarget(name: "SwiftCodeLSPTests", dependencies: ["SwiftCodeLSP"]),
        .testTarget(name: "SwiftCodeRemoteTests", dependencies: ["SwiftCodeRemote"]),
        .testTarget(name: "SwiftCodeVimTests", dependencies: ["SwiftCodeVim"]),
        .testTarget(name: "SwiftCodeNativeTests", dependencies: ["SwiftCodeNative"])
    ]
)
