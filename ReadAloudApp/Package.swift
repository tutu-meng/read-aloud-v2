// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReadAloudApp",
    platforms: [
        .iOS(.v17), // Latest stable iOS version
        .macOS(.v14) // Add macOS support for building
    ],
    products: [
        .library(
            name: "ReadAloudApp",
            targets: ["ReadAloudApp"]),
    ],
    dependencies: [
        // Dependencies will be added here as needed
    ],
    targets: [
        .target(
            name: "ReadAloudApp",
            dependencies: [],
            path: "Sources/ReadAloudApp"
        ),
        .testTarget(
            name: "ReadAloudAppTests",
            dependencies: ["ReadAloudApp"],
            path: "Tests/ReadAloudAppTests"
        ),
    ]
) 