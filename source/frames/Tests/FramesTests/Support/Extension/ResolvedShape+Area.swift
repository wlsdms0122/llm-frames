//
//  ResolvedShape+Area.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

@testable import Frames

// A rect placed by its area with no outset, filled with a colour or stroked, with square corners, no trim and no
// shadow.
extension ResolvedShape {
    // MARK: - Property
    // MARK: - Initializer
    init(
        area: [Keyframe<Rectangle>],
        fill: Color?,
        stroke: PathStroke? = nil
    ) {
        self.init(
            kind: .rect,
            geometry: .area(area, outset: 0),
            radius: [Keyframe(at: 0, value: 0)],
            trim: [Keyframe(at: 0, value: .whole)],
            fill: fill,
            stroke: stroke,
            shadow: nil
        )
    }

    // MARK: - Public
    // MARK: - Private
}
