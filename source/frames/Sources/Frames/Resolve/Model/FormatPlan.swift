//
//  FormatPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The output frame of a sequence in output pixels. `conform` is how storyline crops fill it, `colorSpace` the space its
// output is in, `peak` the mastering peak of a `rec2100-pq` sequence in cd/m² and nil in any other space, and
// `compositing` the form its sums of colours are taken in. `margin` is the room a content-fit frame leaves round what it
// measures, nil for a frame of a written or default size.
struct FormatPlan: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let conform: Conform
    let background: Color
    let fps: Double
    let duration: Double
    let colorSpace: ColorSpace
    let peak: Double?
    let compositing: Compositing
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
        colorSpace: ColorSpace = .srgb,
        peak: Double? = nil,
        compositing: Compositing = .encoded,
        margin: Margin? = nil
    ) {
        self.size = size
        self.conform = conform
        self.background = background
        self.fps = fps
        self.duration = duration
        self.colorSpace = colorSpace
        self.peak = peak
        self.compositing = compositing
        self.margin = margin
    }

    // MARK: - Public
    // MARK: - Private
}
