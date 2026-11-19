//
//  FacelessShaper.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Frames

// A fake shaping provider that finds no face, in a file or on the machine, and sets no glyph.
struct FacelessShaper: ShapingProvider {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func faces(
        family: String,
        in files: [String]
    ) -> [FontFace] {
        []
    }

    func face(
        named name: String,
        in file: String
    ) -> FontFace? {
        nil
    }

    func installedFaces(family: String) -> [FontFace] {
        []
    }

    func shape(
        _ text: String,
        faces: [FontFace],
        size: Double,
        features: [FontFeature],
        weight: FontWeight,
        italic: Bool
    ) -> [ShapedRun] {
        []
    }

    // MARK: - Private
}
