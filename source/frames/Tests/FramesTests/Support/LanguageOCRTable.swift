//
//  LanguageOCRTable.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames

// A fake OCR provider that recognises the lines of `table` only when it is asked for exactly `languages`, so a test
// tells which recognition languages reached it by whether text is found.
struct LanguageOCRTable: OCRProvider {
    // MARK: - Property
    let languages: [LanguageTag]?
    let table: OCRTable

    // MARK: - Initializer
    init(
        languages: [LanguageTag]?,
        table: OCRTable
    ) {
        self.languages = languages
        self.table = table
    }

    // MARK: - Public
    func lines(
        in file: MediaFile,
        atMediaTime time: Double,
        languages: [LanguageTag]?
    ) throws -> [RecognisedLine] {
        guard languages == self.languages else { return [] }

        return try table.lines(in: file, atMediaTime: time, languages: languages)
    }

    // MARK: - Private
}
