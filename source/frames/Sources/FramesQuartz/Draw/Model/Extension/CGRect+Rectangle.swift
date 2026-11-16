//
//  CGRect+Rectangle.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Frames

extension CGRect {
    // MARK: - Property
    // MARK: - Initializer
    init(_ rectangle: Rectangle) {
        self.init(x: rectangle.x, y: rectangle.y, width: rectangle.width, height: rectangle.height)
    }

    // MARK: - Public
    // MARK: - Private
}
