//
//  FailingOCR.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames

// A fake OCR provider that fails on every picture with `failure`.
struct FailingOCR: OCRProvider {
    // MARK: - Property
    let failure: ProviderFailure

    // MARK: - Initializer
    init(_ failure: ProviderFailure) {
        self.failure = failure
    }

    // MARK: - Public
    func lines(
        in file: MediaFile,
        atMediaTime time: Double,
        languages: [LanguageTag]?
    ) throws -> [RecognisedLine] {
        throw failure
    }

    // MARK: - Private
}
