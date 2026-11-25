//
//  TimelineBox.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// Where a clip's box lies at the time `timeline --at` names: `rect`, the box in the coordinates of the clip's own space,
// and `quad`, its four corners in output pixels, clockwise from its top left. H(rect → quad) takes the clip's own
// content to output pixels (FRAMES-23).
struct TimelineBox: Equatable, Sendable {
    // MARK: - Property
    let rect: Rectangle
    let quad: Quad

    // MARK: - Initializer
    init(
        rect: Rectangle,
        quad: Quad
    ) {
        self.rect = rect
        self.quad = quad
    }

    // MARK: - Public
    // MARK: - Private
}
