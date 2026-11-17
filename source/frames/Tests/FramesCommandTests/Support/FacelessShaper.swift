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
    func face(
        family: String,
        weight: FontWeight,
        in files: [String]
    ) -> FontFace? {
        nil
    }

    func face(
        named name: String,
        in file: String
    ) -> FontFace? {
        nil
    }

    func installedFace(
        family: String,
        weight: FontWeight
    ) -> FontFace? {
        nil
    }

    func shape(
        _ text: String,
        face: FontFace,
        size: Double
    ) -> [ShapedRun] {
        []
    }

    // MARK: - Private
}
