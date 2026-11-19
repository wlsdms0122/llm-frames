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
    func face(
        family: String,
        weight: FontWeight,
        in files: [String]
    ) -> FontFace? {
        faces.face(family: family, weight: weight, in: files)
    }

    func face(
        named name: String,
        in file: String
    ) -> FontFace? {
        faces.face(named: name, in: file)
    }

    func installedFace(
        family: String,
        weight: FontWeight
    ) -> FontFace? {
        faces.installedFace(family: family, weight: weight)
    }

    func shape(
        _ text: String,
        face: FontFace,
        size: Double
    ) throws -> [ShapedRun] {
        throw failure
    }

    // MARK: - Private
}
