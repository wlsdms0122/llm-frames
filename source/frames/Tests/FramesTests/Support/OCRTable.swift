//
//  OCRTable.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

@testable import Frames

// A fake OCR provider: for each file, the lines recognised from each media time on, so a test tells which frame was
// read by what it finds. A page of a PDF is held as `<file>#<page>`. A file it does not hold has no lines.
struct OCRTable: OCRProvider {
    // MARK: - Property
    let files: [String: [(from: Double, lines: [RecognisedLine])]]

    // MARK: - Initializer
    init(_ files: [String: [(from: Double, lines: [RecognisedLine])]]) {
        self.files = files
    }

    // A file whose lines are the same on every frame.
    init(file: String, lines: [RecognisedLine]) {
        self.init([file: [(from: 0, lines: lines)]])
    }

    // MARK: - Public
    func lines(
        in file: MediaFile,
        atMediaTime time: Double,
        languages: [LanguageTag]?,
        colorSpace: ColorSpace?
    ) throws -> [RecognisedLine] {
        let key = file.page.map { "\(file.path)#\($0)" } ?? file.path

        return (files[key] ?? []).last { $0.from <= time }?.lines ?? []
    }

    // MARK: - Private
}
