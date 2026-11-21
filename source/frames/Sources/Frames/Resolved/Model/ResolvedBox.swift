//
//  ResolvedBox.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Where a clip with a box of its own is drawn: `size` in output pixels, `anchor` the point scale and rotation act
// around, in the box's own pixels, and `position` where that point goes, keyframes in sequence time, each a point or a
// point of a clip area. A parented clip's position is in its parent's space.
struct ResolvedBox: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let position: FollowedValue<GeometryPoint>
    let anchor: Point

    // MARK: - Initializer
    init(
        size: Size,
        position: FollowedValue<GeometryPoint>,
        anchor: Point
    ) {
        self.size = size
        self.position = position
        self.anchor = anchor
    }

    // MARK: - Public
    // MARK: - Private
}
