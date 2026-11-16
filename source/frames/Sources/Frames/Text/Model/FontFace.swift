//
//  FontFace.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A face in a font file, as the shaping provider found it. `name` is the face within the file, and `ascent` and
// `descent` are its extent above and below the baseline at a size of 1.
package struct FontFace: Equatable, Sendable {
    // MARK: - Property
    package let file: String
    package let name: String
    package let ascent: Double
    package let descent: Double

    // MARK: - Initializer
    package init(
        file: String,
        name: String,
        ascent: Double,
        descent: Double
    ) {
        self.file = file
        self.name = name
        self.ascent = ascent
        self.descent = descent
    }

    // MARK: - Public
    // MARK: - Private
}
