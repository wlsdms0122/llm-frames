//
//  FontFace.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A face in a font file, as the shaping provider found it. `name` is the face within the file. `weight`, `width` (the
// OS/2 width class, 5 for normal) and `style` are what its OS/2 table declares, which face matching reads. `ascent`,
// `descent` and the `post` underline's `underlineOffset` (from the baseline down to its top edge) and
// `underlineThickness` are at a size of 1.
package struct FontFace: Equatable, Sendable {
    // MARK: - Property
    package let file: String
    package let name: String
    package let weight: FontWeight
    package let width: Int
    package let style: FontStyle
    package let ascent: Double
    package let descent: Double
    package let underlineOffset: Double
    package let underlineThickness: Double

    // MARK: - Initializer
    package init(
        file: String,
        name: String,
        weight: FontWeight,
        width: Int,
        style: FontStyle,
        ascent: Double,
        descent: Double,
        underlineOffset: Double,
        underlineThickness: Double
    ) {
        self.file = file
        self.name = name
        self.weight = weight
        self.width = width
        self.style = style
        self.ascent = ascent
        self.descent = descent
        self.underlineOffset = underlineOffset
        self.underlineThickness = underlineThickness
    }

    // MARK: - Public
    // MARK: - Private
}
