//
//  Rectangle+VisionBox.swift
//  FramesVision
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import Frames

// Vision's boxes are fractions of the picture from its bottom left, and rectangles are in media pixels from its top
// left.
extension Rectangle {
    // MARK: - Property
    // MARK: - Initializer
    init(
        visionBox box: CGRect,
        in size: Size
    ) {
        self.init(
            x: box.minX * size.width,
            y: (1 - box.maxY) * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        )
    }

    // MARK: - Public
    func visionBox(in size: Size) -> CGRect {
        CGRect(
            x: x / size.width,
            y: 1 - (y + height) / size.height,
            width: width / size.width,
            height: height / size.height
        )
    }

    // MARK: - Private
}
