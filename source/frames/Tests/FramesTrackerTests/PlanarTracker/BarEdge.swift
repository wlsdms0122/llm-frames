//
//  BarEdge.swift
//  FramesTrackerTests
//
//  Created by JSilver on 11/22/26.
//

import Frames

// The edge of a target a bar covering it grows from, across the rectangle that bounds the target's corners and 40
// pixels past it on the other three sides.
enum BarEdge: String, Sendable {
    case left
    case top

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The bar over `share` of the bounds of `corners`.
    func bar(
        covering share: Double,
        of corners: Quad
    ) -> Rectangle {
        let xs = corners.corners.map(\.x)
        let ys = corners.corners.map(\.y)
        let left = xs.min() ?? 0
        let top = ys.min() ?? 0
        let width = (xs.max() ?? 0) - left
        let height = (ys.max() ?? 0) - top
        switch self {
        case .left:
            return Rectangle(x: left - 40, y: top - 40, width: 40 + share * width, height: height + 80)

        case .top:
            return Rectangle(x: left - 40, y: top - 40, width: width + 80, height: 40 + share * height)
        }
    }

    // MARK: - Private
}
