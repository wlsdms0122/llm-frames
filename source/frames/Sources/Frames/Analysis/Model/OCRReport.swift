//
//  OCRReport.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What `ocr` prints: the picture's size and the lines recognised on each frame read, in media pixels. An image has
// one frame at time 0.
package struct OCRReport: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let frames: [OCRFrame]

    // MARK: - Initializer
    init(
        size: Size,
        frames: [OCRFrame]
    ) {
        self.size = size
        self.frames = frames
    }

    // MARK: - Public
    // MARK: - Private
}
