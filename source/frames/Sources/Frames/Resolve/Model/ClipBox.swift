//
//  ClipBox.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Where a clip with a box of its own is drawn: `size`, its box in output pixels, `anchor`, the point scale and rotation
// act around, in the box's own pixels, and `position`, where that point goes, with keyframes in sequence time, each a
// point or a point of a clip area. A parented clip's position is in its parent's space. `placement` is how a box placed
// by a placement name sits inside the frame, which places it again on a content-fit frame once that is measured, and
// nil for a box placed by its position.
struct ClipBox: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let position: PropertyValue<GeometryPoint>
    let anchor: Point
    let placement: BoxPlacement?

    // MARK: - Initializer
    init(
        size: Size,
        position: PropertyValue<GeometryPoint>,
        anchor: Point,
        placement: BoxPlacement? = nil
    ) {
        self.size = size
        self.position = position
        self.anchor = anchor
        self.placement = placement
    }

    // MARK: - Public
    // MARK: - Private
}
