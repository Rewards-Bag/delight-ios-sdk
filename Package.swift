// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DelightSDK",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "DelightSDK",
            targets: ["DelightSDK"]
        )
    ],
    targets: [
        .target(
            name: "DelightSDK",
            path: "sdk",
            resources: [
                .process("config.json"),
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "DelightSDKTests",
            dependencies: ["DelightSDK"],
            path: "sdkTests"
        )
    ]
)
