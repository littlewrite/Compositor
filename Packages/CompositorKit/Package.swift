// swift-tools-version: 5.9
import PackageDescription

/// Shared, platform-neutral code. Nothing here may import AppKit or UIKit, so the package
/// builds and links the same way for macOS and iPadOS.
let package = Package(
    name: "CompositorKit",
    platforms: [.macOS("15.0"), .iOS("15.0")],
    products: [
        .library(name: "CompositorCore", targets: ["CompositorCore"]),
    ],
    targets: [
        .target(
            name: "CompositorCore",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
    ]
)
