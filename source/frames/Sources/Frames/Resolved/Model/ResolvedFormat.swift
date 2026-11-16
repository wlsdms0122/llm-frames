//
//  ResolvedFormat.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The output frame of a sequence in output pixels, its frame rate and duration (the sequence end), the colour behind
// everything, the content rect, and how storyline crops were conformed to it.
struct ResolvedFormat: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let fps: Double
    let duration: Double
    let background: Color
    let content: Rectangle
    let conform: Conform

    // MARK: - Initializer
    init(
        size: Size,
        fps: Double,
        duration: Double,
        background: Color,
        content: Rectangle,
        conform: Conform
    ) {
        self.size = size
        self.fps = fps
        self.duration = duration
        self.background = background
        self.content = content
        self.conform = conform
    }

    // MARK: - Public
    // MARK: - Private
}
