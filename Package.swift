// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "EchoFS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EchoFS", targets: ["EchoFS"])
    ],
    dependencies: [
        .package(url: "https://github.com/Justmalhar/WhisperCppKit.git", from: "0.1.1"),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.1"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
    ],
    targets: [
        .executableTarget(
            name: "EchoFS",
            dependencies: [
                .product(name: "WhisperCppKit", package: "WhisperCppKit"),
                "HotKey",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "EchoFS/Sources",
            resources: [
                .process("../Resources"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=minimal"),
            ]
        ),
        .testTarget(
            name: "EchoFSTests",
            dependencies: ["EchoFS"],
            path: "EchoFSTests"
        ),
    ]
)
