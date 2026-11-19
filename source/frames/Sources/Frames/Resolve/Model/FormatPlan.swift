//
//  FormatPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The output frame of a sequence in output pixels. `conform` is how storyline crops fill it. `margin` is the room a
// content-fit frame leaves round what it measures, nil for a frame of a written or default size.
struct FormatPlan: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let conform: Conform
    let background: Color
    let fps: Double
    let duration: Double
    let margin: Margin?

    var frame: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // A content-fit frame is measured from what its sequence draws, which is planned in the measuring space first.
    var isMeasured: Bool {
        margin != nil
    }

    // MARK: - Initializer
    init(
        size: Size,
        conform: Conform,
        background: Color,
        fps: Double,
        duration: Double,
        margin: Margin? = nil
    ) {
        self.size = size
        self.conform = conform
        self.background = background
        self.fps = fps
        self.duration = duration
        self.margin = margin
    }

    // MARK: - Public
    // MARK: - Private
}
