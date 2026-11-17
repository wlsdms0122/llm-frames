//
//  ClipBox.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Where a title or media clip is drawn: `size`, its box in output pixels, `position`, the top left of the box with
// keyframes in sequence time, and `anchor`, the point scale and rotation act around, in the box's own pixels. A
// parented clip's position is in its parent's space, and its anchor point there is `position + anchor`.
struct ClipBox: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let position: PropertyValue<Point>
    let anchor: Point

    // MARK: - Initializer
    init(
        size: Size,
        position: PropertyValue<Point>,
        anchor: Point
    ) {
        self.size = size
        self.position = position
        self.anchor = anchor
    }

    // MARK: - Public
    // MARK: - Private
}
