//
//  ClipCornerPin.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Where a clip with a corner pin is drawn: `size`, its box in output pixels, and `points`, the four points its box's
// top left, top right, bottom right and bottom left corners go to in the clip's coordinate space, with keyframes in
// sequence time, each a point or a point of a clip area (FRAMES-27). A parented clip's points are in its parent's space.
struct ClipCornerPin: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let points: PropertyValue<[GeometryPoint]>

    // MARK: - Initializer
    init(
        size: Size,
        points: PropertyValue<[GeometryPoint]>
    ) {
        self.size = size
        self.points = points
    }

    // MARK: - Public
    // MARK: - Private
}
