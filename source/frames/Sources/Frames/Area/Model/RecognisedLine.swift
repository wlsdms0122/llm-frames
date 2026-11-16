//
//  RecognisedLine.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A line the OCR provider recognised: its text and its rectangle in media pixels.
package struct RecognisedLine: Equatable, Sendable {
    // MARK: - Property
    package let text: String
    package let rectangle: Rectangle

    // MARK: - Initializer
    package init(
        text: String,
        rectangle: Rectangle
    ) {
        self.text = text
        self.rectangle = rectangle
    }

    // MARK: - Public
    // MARK: - Private
}
