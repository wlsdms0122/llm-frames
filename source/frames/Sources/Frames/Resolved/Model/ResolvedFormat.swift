//
//  ResolvedFormat.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The output frame of a sequence in output pixels, its frame rate and duration (the sequence end), the colour behind
// everything, and how storyline crops were conformed to it.
struct ResolvedFormat: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let fps: Double
    let duration: Double
    let background: Color
    let conform: Conform

    var frame: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // MARK: - Initializer
    init(
        size: Size,
        fps: Double,
        duration: Double,
        background: Color,
        conform: Conform
    ) {
        self.size = size
        self.fps = fps
        self.duration = duration
        self.background = background
        self.conform = conform
    }

    // MARK: - Public
    // MARK: - Private
}
