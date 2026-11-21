//
//  PageRasterizerTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/22/26.
//

import CoreGraphics
import Foundation
@testable import FramesAVFoundation
import Testing

@Suite("PageRasterizer Tests")
struct PageRasterizerTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a bitmap the page cannot be drawn in stops, rather than giving a transparent picture")
    func refusesBitmapThatCannotBeMade() throws {
        // Given
        let file = PDFFileWriter.document(pages: [[
            "MediaBox": .array([0, 0, 4, 4].map(PDFValue.integer)),
            "Contents": PDFFileWriter.content("1 g 0 0 4 4 re f")
        ]])
        let page = try #require(CGDataProvider(data: file as CFData).flatMap(CGPDFDocument.init)?.page(at: 1))
        let space = try #require(CGColorSpace(name: CGColorSpace.genericCMYK))

        // When, Then
        #expect(throws: DecoderError.pageBitmap(width: 4, height: 4)) {
            try PageRasterizer.pixels(of: page, width: 4, height: 4, transform: .identity, clip: nil, space: space)
        }
    }

    @Test("a page is drawn into a bitmap of the size asked for")
    func drawsPage() throws {
        // Given
        let file = PDFFileWriter.document(pages: [[
            "MediaBox": .array([0, 0, 4, 4].map(PDFValue.integer)),
            "Contents": PDFFileWriter.content("1 g 0 0 4 4 re f")
        ]])
        let page = try #require(CGDataProvider(data: file as CFData).flatMap(CGPDFDocument.init)?.page(at: 1))
        let space = try #require(CGColorSpace(name: CGColorSpace.extendedSRGB))

        // When
        let pixels = try PageRasterizer.pixels(of: page, width: 4, height: 4, transform: .identity, clip: nil, space: space)

        // Then
        #expect(pixels.count == 4 * 4 * 4)
        #expect(pixels.allSatisfy { abs($0 - 1) < 1e-6 })
    }
}
