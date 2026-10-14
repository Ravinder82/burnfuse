// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BurnFuse",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BurnFuseUI", targets: ["BurnFuseUI"]),
        .executable(name: "BurnFuse", targets: ["BurnFuse"]),
        .executable(name: "burnfuse-shots", targets: ["burnfuse-shots"]),
    ],
    targets: [
        .target(
            name: "BurnFuseUI",
            path: "Sources/BurnFuseUI"
        ),
        .executableTarget(
            name: "BurnFuse",
            dependencies: ["BurnFuseUI"],
            path: "Sources/BurnFuse"
        ),
        .executableTarget(
            name: "burnfuse-shots",
            dependencies: ["BurnFuseUI"],
            path: "Sources/burnfuse-shots"
        ),
        .testTarget(
            name: "BurnFuseUITests",
            dependencies: ["BurnFuseUI"],
            path: "Tests/BurnFuseUITests",
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)