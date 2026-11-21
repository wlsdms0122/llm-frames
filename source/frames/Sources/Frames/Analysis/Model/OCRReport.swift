//
//  OCRReport.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What `ocr` prints: the picture's size, the recognition languages asked for, nil where the provider detected them,
// and the lines recognised on each frame read, in media pixels, which a page of a PDF has in points. A still has one
// frame at time 0.
package struct OCRReport: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let languages: [LanguageTag]?
    package let frames: [OCRFrame]

    // MARK: - Initializer
    init(
        size: Size,
        languages: [LanguageTag]?,
        frames: [OCRFrame]
    ) {
        self.size = size
        self.languages = languages
        self.frames = frames
    }

    // MARK: - Public
    // MARK: - Private
}
