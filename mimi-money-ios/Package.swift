// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MimiMoney",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MimiMoneyCore",
            targets: ["MimiMoneyCore"]
        ),
        .executable(
            name: "MimiMoneyApp",
            targets: ["MimiMoneyApp"]
        )
    ],
    targets: [
        .target(
            name: "MimiMoneyCore",
            path: "Sources/MimiMoneyCore"
        ),
        .executableTarget(
            name: "MimiMoneyApp",
            dependencies: ["MimiMoneyCore"],
            path: "Sources/MimiMoneyApp"
        ),
        .testTarget(
            name: "MimiMoneyTests",
            dependencies: ["MimiMoneyCore"],
            path: "Tests/MimiMoneyTests"
        )
    ]
)
