//
//  TextRun.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

struct TextRun: Equatable, Sendable {
    // MARK: - Property
    let text: String
    let style: CharacterStyle
    let face: FontFace

    // MARK: - Initializer
    init(
        text: String,
        style: CharacterStyle,
        face: FontFace
    ) {
        self.text = text
        self.style = style
        self.face = face
    }

    // MARK: - Public
    // MARK: - Private
}
