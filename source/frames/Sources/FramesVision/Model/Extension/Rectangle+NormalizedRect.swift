//
//  Rectangle+NormalizedRect.swift
//  FramesVision
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import Frames

// Vision's normalized rects are fractions of the picture from its bottom left, and rectangles are in media pixels
// from its top left.
extension Rectangle {
    // MARK: - Property
    // MARK: - Initializer
    init(
        normalizedRect rect: CGRect,
        in size: Size
    ) {
        self.init(
            x: rect.minX * size.width,
            y: (1 - rect.maxY) * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    // MARK: - Public
    func normalizedRect(in size: Size) -> CGRect {
        CGRect(
            x: x / size.width,
            y: 1 - (y + height) / size.height,
            width: width / size.width,
            height: height / size.height
        )
    }

    // MARK: - Private
}
