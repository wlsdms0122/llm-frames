//
//  AVFoundationDecoderPageCountTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation
import Frames
import FramesAVFoundation
import FramesTestMedia
import Testing

@Suite("AVFoundationDecoder Page Count Tests")
struct AVFoundationDecoderPageCountTests {
    // MARK: - Property
    private let sut = AVFoundationDecoder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a PDF's page count is the number of pages it holds")
    func countsPages() throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("deck.pdf")
        try writePDF(pageCount: 3, to: file)

        // When
        let count = try sut.pageCount(of: file)

        // Then
        #expect(count == 3)
    }

    @Test("a file that is not a PDF, and a file that is not there, have no page count")
    func countsNoPagesOutsidePDF() throws {
        // Given
        let directory = try TemporaryDirectory()
        let image = directory.file("card.png")
        try ImageWriter(size: Size(width: 8, height: 8)).write(to: image) { _ in }

        // When
        let count = try sut.pageCount(of: image)

        // Then
        #expect(count == nil)
        #expect(try sut.pageCount(of: directory.file("missing.pdf")) == nil)
    }

    // MARK: - Private
    private func writePDF(
        pageCount: Int,
        to file: String
    ) throws {
        var box = CGRect(x: 0, y: 0, width: 200, height: 100)
        guard let context = CGContext(URL(fileURLWithPath: file) as CFURL, mediaBox: &box, nil) else {
            Issue.record("no PDF context")
            return
        }
        for _ in 0..<pageCount {
            context.beginPDFPage(nil)
            context.endPDFPage()
        }
        context.closePDF()
    }
}
