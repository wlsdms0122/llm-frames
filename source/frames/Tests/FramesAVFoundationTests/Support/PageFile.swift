//
//  PageFile.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
@testable import FramesAVFoundation

// Hand-written PDFs of pages for the decoder's page tests: each page a media box, resources, a content stream and any
// further page keys.
struct PageFile {
    // MARK: - Property
    // A Type 1 font with no descriptor, which the file does not embed.
    static let helvetica = PDFValue.dictionary([
        "Type": .name("Font"),
        "Subtype": .name("Type1"),
        "BaseFont": .name("Helvetica")
    ])

    // A TrueType font whose descriptor holds a font file. The file is not a font, which no check reads.
    static let embedded = PDFValue.dictionary([
        "Type": .name("Font"),
        "Subtype": .name("TrueType"),
        "BaseFont": .name("Embedded"),
        "FontDescriptor": .dictionary([
            "Type": .name("FontDescriptor"),
            "FontName": .name("Embedded"),
            "FontFile2": .stream([:], Data([0]))
        ])
    ])

    // MARK: - Initializer
    // MARK: - Public
    static func page(
        _ operators: String,
        resources: [String: PDFValue] = [:],
        mediaBox: [Int] = [0, 0, 400, 300],
        entries: [String: PDFValue] = [:]
    ) -> [String: PDFValue] {
        [
            "MediaBox": .array(mediaBox.map(PDFValue.integer)),
            "Resources": .dictionary(resources),
            "Contents": PDFFileWriter.content(operators)
        ].merging(entries) { _, entry in entry }
    }

    // A file of `pages` written to `path`.
    static func write(
        _ pages: [[String: PDFValue]],
        to path: String,
        catalog: [String: PDFValue] = [:],
        writer: PDFFileWriter = PDFFileWriter()
    ) throws {
        try PDFFileWriter.document(pages: pages, catalog: catalog, writer: writer).write(to: URL(fileURLWithPath: path))
    }

    // MARK: - Private
}
