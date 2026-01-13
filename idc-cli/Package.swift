// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "idc",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.14.1"),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "idc",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "Subprocess", package: "swift-subprocess"),
            ]
        ),
        .testTarget(
            name: "idcTests",
            dependencies: ["idc"]
        ),
    ]
)
