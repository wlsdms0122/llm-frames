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
            geometry: .area(.keyframes(area.map { $0.map(GeometryArea.rectangle) }), outset: 0, placement: GeometryPlacement()),
            radius: .off,
            trim: [Keyframe(at: 0, value: .whole)],
            fill: .fill(fill),
            stroke: .stroke(stroke),
            shadow: .off
        )
    }

    // MARK: - Public
    // MARK: - Private
}
