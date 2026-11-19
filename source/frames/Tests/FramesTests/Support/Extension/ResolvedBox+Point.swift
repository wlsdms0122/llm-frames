//
//  ResolvedBox+Point.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames

// A box whose position holds no clip area.
extension ResolvedBox {
    // MARK: - Property
    // MARK: - Initializer
    init(
        size: Size,
        position: [Keyframe<Point>],
        anchor: Point
    ) {
        self.init(size: size, position: position.map { $0.map(GeometryPoint.point) }, anchor: anchor)
    }

    // MARK: - Public
    // MARK: - Private
}
