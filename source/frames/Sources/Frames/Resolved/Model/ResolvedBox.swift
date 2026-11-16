//
//  ResolvedBox.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Where a title or media clip is drawn: `size` in output pixels, `position` the top left of the box with keyframes in
// sequence time, and `anchor` the point scale and rotation act around, in the box's own pixels. A parented clip's
// position is in the media pixels of its picture.
struct ResolvedBox: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let position: [Keyframe<Point>]
    let anchor: Point

    // MARK: - Initializer
    init(
        size: Size,
        position: [Keyframe<Point>],
        anchor: Point
    ) {
        self.size = size
        self.position = position
        self.anchor = anchor
    }

    // MARK: - Public
    // MARK: - Private
}
