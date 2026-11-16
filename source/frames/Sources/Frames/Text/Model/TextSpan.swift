//
//  TextSpan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A piece of text in one colour: the style's colour, or its emphasis colour for `**text**`.
struct TextSpan: Equatable, Sendable {
    // MARK: - Property
    let text: String
    let color: Color

    // MARK: - Initializer
    init(
        text: String,
        color: Color
    ) {
        self.text = text
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}
