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
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", .upToNextMinor(from: "0.14.2")),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.19"))
    ],
    targets: [
        .target(
            name: "MimiMoneyCore",
            dependencies: [
                .product(name: "CoreXLSX", package: "CoreXLSX"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Sources/MimiMoneyCore",
            resources: [
                .process("Resources")
            ]
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
