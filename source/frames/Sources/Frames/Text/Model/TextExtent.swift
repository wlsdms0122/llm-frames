//
//  TextExtent.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

struct TextExtent: Equatable, Sendable {
    // MARK: - Property
    let ascent: Double
    let descent: Double

    // MARK: - Initializer
    init(
        face: FontFace,
        size: Double
    ) {
        self.ascent = face.ascent * size
        self.descent = face.descent * size
    }

    // MARK: - Public
    // MARK: - Private
}
