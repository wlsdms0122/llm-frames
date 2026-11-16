//
//  FormatPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The output frame of a sequence and its content rect, in output pixels, with how storyline crops fill that rect, the
// colour behind everything, the frame rate it renders at alone, and its duration, the sequence end.
struct FormatPlan: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let content: Rectangle
    let conform: Conform
    let background: Color
    let fps: Double
    let duration: Double

    var frame: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // MARK: - Initializer
    init(
        size: Size,
        content: Rectangle,
        conform: Conform,
        background: Color,
        fps: Double,
        duration: Double
    ) {
        self.size = size
        self.content = content
        self.conform = conform
        self.background = background
        self.fps = fps
        self.duration = duration
    }

    // MARK: - Public
    // MARK: - Private
}
