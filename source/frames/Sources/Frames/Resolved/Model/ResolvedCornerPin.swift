//
//  ResolvedCornerPin.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Where a clip with a corner pin is drawn: `size`, its box B in output pixels, and `points`, keyframes in sequence time
// of the four points B's top left, top right, bottom right and bottom left corners go to in the clip's coordinate
// space, each a point or a point of a clip area (FRAMES-27). On a tracked clip they are the corner pins as written, at
// their own times. A parented clip's points are in its parent's space.
struct ResolvedCornerPin: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let points: FollowedValue<GeometryQuad>

    // MARK: - Initializer
    init(
        size: Size,
        points: FollowedValue<GeometryQuad>
    ) {
        self.size = size
        self.points = points
    }

    // MARK: - Public
    // MARK: - Private
}
