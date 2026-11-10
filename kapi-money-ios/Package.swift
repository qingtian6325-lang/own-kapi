// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KapiMoney",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "KapiMoneyCore",
            targets: ["KapiMoneyCore"]
        ),
        .executable(
            name: "KapiMoneyApp",
            targets: ["KapiMoneyApp"]
        )
    ],
    targets: [
        .target(
            name: "KapiMoneyCore",
            path: "Sources/KapiMoneyCore"
        ),
        .executableTarget(
            name: "KapiMoneyApp",
            dependencies: ["KapiMoneyCore"],
            path: "Sources/KapiMoneyApp"
        ),
        .testTarget(
            name: "KapiMoneyTests",
            dependencies: ["KapiMoneyCore"],
            path: "Tests/KapiMoneyTests"
        )
    ]
)
