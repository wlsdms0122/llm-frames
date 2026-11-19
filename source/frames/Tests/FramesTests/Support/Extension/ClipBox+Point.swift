//
//  ClipBox+Point.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames

// A box whose position holds no clip area.
extension ClipBox {
    // MARK: - Property
    // MARK: - Initializer
    init(
        size: Size,
        position: PropertyValue<Point>,
        anchor: Point
    ) {
        self.init(size: size, position: position.map(GeometryPoint.point), anchor: anchor)
    }

    // MARK: - Public
    // MARK: - Private
}
