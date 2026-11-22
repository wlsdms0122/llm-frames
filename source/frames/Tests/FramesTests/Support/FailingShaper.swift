//
//  FailingShaper.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames

// A fake shaping provider that finds faces as `ShaperTable` does and fails on every run of text with `failure`.
struct FailingShaper: ShapingProvider {
    // MARK: - Property
    let failure: ProviderFailure
    private let faces = ShaperTable()

    // MARK: - Initializer
    init(_ failure: ProviderFailure) {
        self.failure = failure
    }

    // MARK: - Public
    func faces(
        family: String,
        in files: [String]
    ) -> [FontFace] {
        faces.faces(family: family, in: files)
    }

    func face(
        named name: String,
        in file: String
    ) -> FontFace? {
        faces.face(named: name, in: file)
    }

    func installedFaces(family: String) -> [FontFace] {
        faces.installedFaces(family: family)
    }

    func shape(
        _ text: String,
        direction: TextDirection,
        faces: [FontFace],
        size: Double,
        features: [FontFeature],
        weight: FontWeight,
        italic: Bool
    ) throws -> [ShapedRun] {
        throw failure
    }

    // MARK: - Private
}
