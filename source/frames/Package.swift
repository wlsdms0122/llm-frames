// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Frames",
    platforms: [
        .macOS(.v14)
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
            name: "FramesCoreText",
            dependencies: ["Frames"]
        ),
        .target(
            name: "FramesPointTracker",
            dependencies: ["Frames"]
        ),
        .target(
            name: "FramesQuartz",
            dependencies: ["Frames"]
        ),
        .target(
            name: "FramesTestMedia",
            dependencies: ["Frames"],
            path: "Tests/FramesTestMedia"
        ),
        .testTarget(
            name: "FramesTests",
            dependencies: [
                "Frames",
                "FramesAVFoundation",
                "FramesVision",
                "FramesCoreText",
                "FramesPointTracker",
                "FramesTestMedia"
            ]
        ),
        .testTarget(
            name: "FramesAVFoundationTests",
            dependencies: ["FramesAVFoundation", "FramesTestMedia"]
        ),
        .testTarget(
            name: "FramesVisionTests",
            dependencies: ["FramesVision", "FramesAVFoundation", "FramesTestMedia"]
        ),
        .testTarget(
            name: "FramesCoreTextTests",
            dependencies: ["FramesCoreText"]
        ),
        .testTarget(
            name: "FramesPointTrackerTests",
            dependencies: ["FramesPointTracker", "FramesAVFoundation", "FramesTestMedia"]
        ),
        .testTarget(
            name: "FramesQuartzTests",
            dependencies: ["FramesQuartz", "FramesAVFoundation", "FramesTestMedia"]
        ),
        .testTarget(
            name: "FramesRenderTests",
            dependencies: [
                "Frames",
                "FramesAVFoundation",
                "FramesQuartz",
                "FramesVision",
                "FramesCoreText",
                "FramesPointTracker",
                "FramesTestMedia"
            ]
        )
    ]
)
