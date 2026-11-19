//
//  ColorReading.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// How a decoder takes a file's pictures to working values (FRAMES-26 Media): by the fixed formulas, from the colour
// space of the table its tags name, nil for tags outside the table, or only by the platform's own colour management,
// for an image whose ICC profile is LUT-based or a video with code points no formula defines.
package enum ColorReading: Equatable, Sendable {
    case formulas(ColorSpace?)
    case platform

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Whether the fixed formulas convert a picture read this way when it is read in `colorSpace`, or by its tags where
    // that is nil. A written colour space converts any picture, and the tags convert all but a picture only the
    // platform's colour management reads.
    package func converts(in colorSpace: ColorSpace?) -> Bool {
        colorSpace != nil || self != .platform
    }

    // MARK: - Private
}
