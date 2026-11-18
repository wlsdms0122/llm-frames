//
//  Array+MaskBounds.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The bounding box of a clip's masks (FRAMES-12, FRAMES-10, FRAMES-14): the union of each mask's rectangle, or of the
// box of its points for a path, in the clip's own coordinate space and without feather. What `track: true` follows on
// a mask, and the box an adjustment acts around and wipes across. Nil for no masks.
extension Array where Element == ResolvedMask {
    // MARK: - Property
    var bounds: Rectangle? {
        let boxes = map { mask in
            switch mask.geometry {
            case let .rect(rectangle, _), let .ellipse(rectangle):
                rectangle

            case let .polyline(points, _):
                Rectangle(bounding: points)
            }
        }
        guard let first = boxes.first else { return nil }

        return boxes.dropFirst().reduce(first) { $0.union($1) }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
