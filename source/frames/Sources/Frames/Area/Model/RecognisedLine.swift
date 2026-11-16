//
//  RecognisedLine.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A line the OCR provider recognised: its text and its rectangle in media pixels.
struct RecognisedLine: Equatable, Sendable {
    // MARK: - Property
    let text: String
    let rectangle: Rectangle

    // MARK: - Initializer
    init(
        text: String,
        rectangle: Rectangle
    ) {
        self.text = text
        self.rectangle = rectangle
    }

    // MARK: - Public
    // MARK: - Private
}
