// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KotoFloat",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [.library(name: "KotoFloatKit", targets: ["KotoFloatKit"])],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.3.0")
    ],
    targets: [
        .target(name: "KotoFloatKit", dependencies: ["KeyboardShortcuts"],
                resources: [.process("Resources")]),
        .testTarget(name: "KotoFloatKitTests", dependencies: ["KotoFloatKit"])
    ]
)
