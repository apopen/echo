// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Echo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Echo", targets: ["Echo"])
    ],
    dependencies: [
        .package(url: "https://github.com/Justmalhar/WhisperCppKit.git", from: "0.1.1"),
    ],
    targets: [
        .executableTarget(
            name: "Echo",
            dependencies: [
                .product(name: "WhisperCppKit", package: "WhisperCppKit"),
            ],
            path: "Echo/Sources",
            resources: [
                .process("../Resources"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=minimal"),
            ]
        ),
        .testTarget(
            name: "EchoTests",
            dependencies: ["Echo"],
            path: "EchoTests"
        ),
    ]
)
