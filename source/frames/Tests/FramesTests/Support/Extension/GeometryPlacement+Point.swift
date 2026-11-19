//
//  GeometryPlacement+Point.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames

// A placement whose position holds no clip area and whose anchor is a point.
extension GeometryPlacement {
    // MARK: - Property
    // MARK: - Initializer
    init(
        position: [Keyframe<Point>]?,
        anchor: Point?
    ) {
        self.init(position: position?.map { $0.map(GeometryPoint.point) }, anchor: anchor.map(GeometryAnchor.point))
    }

    // MARK: - Public
    // MARK: - Private
}
