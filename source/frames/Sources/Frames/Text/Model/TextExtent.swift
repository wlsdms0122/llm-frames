//
//  TextExtent.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A run's extents on a line, in output pixels: `ascent` on the line-over side of the line's baseline and `descent` on
// its line-under side, and `alphabetic`, how far its alphabetic baseline lies from the line's baseline toward
// line-under. A horizontal line's baseline is the alphabetic one and the extents are the face's. A vertical line's
// baseline is the central one, halfway between the face's ascent and descent, so each extent is half their sum.
struct TextExtent: Equatable, Sendable {
    // MARK: - Property
    let ascent: Double
    let descent: Double
    let alphabetic: Double

    // MARK: - Initializer
    init(
        face: FontFace,
        size: Double,
        writingMode: WritingMode
    ) {
        let ascent = face.ascent * size
        let descent = face.descent * size
        guard writingMode.isVertical else {
            self.ascent = ascent
            self.descent = descent
            self.alphabetic = 0
            return
        }

        self.ascent = (ascent + descent) / 2
        self.descent = (ascent + descent) / 2
        self.alphabetic = (ascent - descent) / 2
    }

    // MARK: - Public
    // MARK: - Private
}
