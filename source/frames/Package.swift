// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Frames",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(name: "Frames"),
        .target(
            name: "FramesAVFoundation",
            dependencies: ["Frames"]
        ),
        .target(
            name: "FramesVision",
            dependencies: ["Frames"]
        ),
        .target(
            name: "FramesTestMedia",
            dependencies: ["Frames"],
            path: "Tests/FramesTestMedia"
        ),
        .testTarget(
            name: "FramesTests",
            dependencies: ["Frames"]
        ),
        .testTarget(
            name: "FramesAVFoundationTests",
            dependencies: ["FramesAVFoundation", "FramesTestMedia"]
        ),
        .testTarget(
            name: "FramesVisionTests",
            dependencies: ["FramesVision", "FramesAVFoundation", "FramesTestMedia"]
        )
    ]
)
