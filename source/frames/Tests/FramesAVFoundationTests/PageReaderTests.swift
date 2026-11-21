//
//  PageReaderTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation
import Frames
@testable import FramesAVFoundation
import FramesTestMedia
import Testing

// The decoder's pages of a PDF (FRAMES-3 PDF pages, FRAMES-21 Rules): probed, checked and drawn by region and scale.
@Suite("PageReader Tests")
struct PageReaderTests {
    // MARK: - Property
    // Rectangles of four colours at fractional positions on a 400 by 300 page.
    private static let rectangles = """
        1 0 0 rg 10.3 20.7 100.2 50.9 re f 0 1 0 rg 150.6 80.1 120.3 90.8 re f
        0 0 1 rg 30.5 200.25 300.7 60.4 re f 0.5 g 280.1 10.9 90.3 270.6 re f
        """

    private let directory: TemporaryDirectory
    private let sut = AVFoundationDecoder()

    // MARK: - Initializer
    init() throws {
        directory = try TemporaryDirectory()
    }

    // MARK: - Test
    @Test("a PDF's probe gives its page count, and a page's its size in points, its crop box cut by its media box and turned by its Rotate")
    func probesPage() throws {
        // Given
        let path = directory.file("pages.pdf")
        try PageFile.write(
            [
                PageFile.page("0 g 0 0 10 10 re f"),
                PageFile.page("0 g 0 0 10 10 re f", entries: [
                    "CropBox": .array([.real(0.5), .integer(0), .real(595.776), .real(841.89)]),
                    "Rotate": .integer(450)
                ])
            ],
            to: path
        )

        // When
        let count = try sut.pageCount(of: path)
        let probed = try sut.probedPage(2, of: path)

        // Then
        #expect(count == 2)
        #expect(abs((probed?.size.width ?? 0) - 300) < 1e-9)
        #expect(abs((probed?.size.height ?? 0) - 399.5) < 1e-9)
        #expect(probed?.pageCount == 2)
    }

    @Test("a file that is not a PDF has no page count, and a page of it or past the count stops")
    func refusesMissingPage() throws {
        // Given
        let path = directory.file("one.pdf")
        try PageFile.write([PageFile.page("0 g 0 0 10 10 re f")], to: path)
        let text = directory.file("notes.txt")
        try Data("notes".utf8).write(to: URL(fileURLWithPath: text))

        // When
        let count = try sut.pageCount(of: text)

        // Then
        #expect(count == nil)
        #expect(throws: DecoderError.noPage(file: path, page: 2, count: 1)) { try sut.probedPage(2, of: path) }
        #expect(throws: DecoderError.noDocument(file: text)) { try sut.probedPage(1, of: text) }
    }

    @Test("a region drawn alone gives the pixels of the same block of the whole page, on rectangles")
    func drawsRegionAsBlockOfWhole() throws {
        // Given
        let path = directory.file("rectangles.pdf")
        try PageFile.write([PageFile.page(Self.rectangles)], to: path)
        let file = MediaFile(path: path, page: 1)
        let whole = PageRegion(wholePageOf: Size(width: 400, height: 300), scale: 1.5)
        let region = PageRegion(x: 150, y: 90, width: 300, height: 180)

        // When
        let wholePicture = try sut.picture(of: file, region: whole, scale: 1.5, reading: .tagged)
        let regionPicture = try sut.picture(of: file, region: region, scale: 1.5, reading: .tagged)

        // Then
        #expect(wholePicture.width == 600)
        #expect(wholePicture.height == 450)
        let wholePixels = wholePicture.floatPixels()
        let regionPixels = regionPicture.floatPixels()
        let differing = (0..<region.height).reduce(0) { count, row in
            count + (0..<region.width * 4).filter { index in
                regionPixels[row * region.width * 4 + index]
                    != wholePixels[(row + region.y) * whole.width * 4 + region.x * 4 + index]
            }.count
        }
        #expect(differing == 0)
    }

    @Test("what the page paints nothing over, and a region past the page, is transparent")
    func leavesUnpaintedTransparent() throws {
        // Given
        let path = directory.file("small.pdf")
        try PageFile.write([PageFile.page("1 0 0 rg 0 0 10 10 re f", mediaBox: [0, 0, 100, 100])], to: path)
        let file = MediaFile(path: path, page: 1)

        // When
        let picture = try sut.picture(of: file, region: PageRegion(x: 0, y: 50, width: 100, height: 100), scale: 1, reading: .tagged)
        let pixels = picture.floatPixels()

        // Then
        #expect(pixels[3] == 0)
        #expect(pixels[((40 * 100) + 5) * 4 + 3] == 1)
        #expect(pixels[((60 * 100) + 60) * 4 + 3] == 0)
    }

    @Test("nothing the page paints outside its crop box is drawn")
    func clipsToCropBox() throws {
        // Given
        let path = directory.file("cropped.pdf")
        try PageFile.write(
            [PageFile.page("1 0 0 rg 0 0 100 100 re f", mediaBox: [0, 0, 100, 100], entries: [
                "CropBox": .array([0, 0, 50, 100].map(PDFValue.integer))
            ])],
            to: path
        )
        let file = MediaFile(path: path, page: 1)

        // When
        let picture = try sut.picture(of: file, region: PageRegion(x: 0, y: 0, width: 100, height: 100), scale: 1, reading: .tagged)
        let pixels = picture.floatPixels()

        // Then
        #expect(pixels[(10 * 100 + 25) * 4 + 3] == 1)
        #expect(pixels[(10 * 100 + 75) * 4 + 3] == 0)
    }

    @Test("a region under 1 pixel, a scale of 0, a region larger than the decoder holds and a frame of a page stop")
    func refusesRequests() throws {
        // Given
        let path = directory.file("request.pdf")
        try PageFile.write([PageFile.page("0 g 0 0 10 10 re f")], to: path)
        let file = MediaFile(path: path, page: 1)
        let largest = sut.largestPictureSide
        let empty = PageRegion(x: 0, y: 0, width: 0, height: 10)
        let large = PageRegion(x: 0, y: 0, width: largest + 1, height: 1)
        let region = PageRegion(x: 0, y: 0, width: 10, height: 10)

        // When
        // Then
        #expect(throws: DecoderError.pageRegion(file: path, region: empty, scale: 1)) {
            try sut.picture(of: file, region: empty, scale: 1, reading: .tagged)
        }
        #expect(throws: DecoderError.pageRegion(file: path, region: region, scale: 0)) {
            try sut.picture(of: file, region: region, scale: 0, reading: .tagged)
        }
        #expect(throws: DecoderError.pictureSize(file: path, width: largest + 1, height: 1, largest: largest)) {
            try sut.picture(of: file, region: large, scale: 1, reading: .tagged)
        }
        #expect(throws: DecoderError.pageFrame(file: path, page: 1)) {
            try sut.picture(of: file, atFrame: 0, reading: .tagged)
        }
    }

    @Test("a page that sets drawn text in a font its file does not embed is refused, naming it and suggesting transcode")
    func refusesUnembeddedFont() throws {
        // Given
        let path = directory.file("font.pdf")
        try PageFile.write(
            [PageFile.page("BT /F1 12 Tf 10 10 Td (a) Tj ET", resources: ["Font": .dictionary(["F1": PageFile.helvetica])])],
            to: path
        )
        let file = MediaFile(path: path, page: 1)

        // When
        let error = #expect(throws: DecoderError.self) { try sut.check(file, reading: .tagged) }

        // Then
        #expect(error == .unreadablePage(file: path, page: 1, fault: .unembeddedFont("Helvetica")))
        #expect(error?.description.contains("transcode") == true)
        #expect(throws: Never.self) { try sut.check(file, reading: .platform(colorSpace: .srgb)) }
    }

    @Test("a page drawn in DeviceCMYK is refused at the probe and at the check")
    func refusesCMYK() throws {
        // Given
        let path = directory.file("cmyk.pdf")
        try PageFile.write([PageFile.page("0 0 0 1 k 0 0 10 10 re f")], to: path)
        let file = MediaFile(path: path, page: 1)

        // When
        // Then
        #expect(throws: DecoderError.self) { try sut.probedPage(1, of: path) }
        #expect(throws: DecoderError.self) { try sut.check(file, reading: nil) }
    }

    @Test("a page drawn in a spot colour whose tint transform is a PostScript calculator function is read by it")
    func readsCalculatorTint() throws {
        // Given
        let path = directory.file("spot.pdf")
        let tint = PDFValue.stream(
            ["FunctionType": .integer(4), "Domain": .array([.integer(0), .integer(1)]), "Range": .array([0, 1, 0, 1, 0, 1].map(PDFValue.integer))],
            Data("{ dup 0.5 mul 0 }".utf8)
        )
        let spot = PDFValue.array([.name("Separation"), .name("Spot"), .name("DeviceRGB"), tint])
        try PageFile.write(
            [PageFile.page("/C0 cs 1 scn 0 0 10 10 re f", resources: ["ColorSpace": .dictionary(["C0": spot])], mediaBox: [0, 0, 10, 10])],
            to: path
        )
        let file = MediaFile(path: path, page: 1)

        // When
        let pixels = try sut.picture(of: file, region: PageRegion(x: 0, y: 0, width: 10, height: 10), scale: 1, reading: .tagged)
            .floatPixels()

        // Then
        #expect(abs(pixels[0] - 1) < 1e-3)
        #expect(abs(pixels[1] - 0.5) < 1e-3)
        #expect(abs(pixels[2]) < 1e-3)
    }

    @Test("a PDF that opens only with a password is refused, and one with an empty user password opens")
    func refusesPassword() throws {
        // Given
        let locked = directory.file("locked.pdf")
        let open = directory.file("open.pdf")
        try writeEncrypted(to: locked, userPassword: "secret")
        try writeEncrypted(to: open, userPassword: "")

        // When
        let count = try sut.pageCount(of: open)

        // Then
        #expect(throws: DecoderError.lockedDocument(file: locked)) { try sut.pageCount(of: locked) }
        #expect(count == 1)
    }

    @Test("the untagged colour read in a written colour space is converted from it")
    func readsUntaggedColorInWrittenSpace() throws {
        // Given
        let path = directory.file("untagged.pdf")
        try PageFile.write([PageFile.page("0 1 0 rg 0 0 10 10 re f", mediaBox: [0, 0, 10, 10])], to: path)
        let file = MediaFile(path: path, page: 1)
        let region = PageRegion(x: 0, y: 0, width: 10, height: 10)

        // When
        let srgb = try sut.picture(of: file, region: region, scale: 1, reading: .tagged).floatPixels()
        let p3 = try sut.picture(of: file, region: region, scale: 1, reading: .working(colorSpace: .displayP3, targetPeak: nil))
            .floatPixels()

        // Then
        #expect(abs(srgb[1] - 1) < 1e-3)
        #expect(p3[0] < -0.1)
        #expect(p3[1] > 1)
    }

    @Test("a written colour space for the untagged colour of a page that draws tagged colour too is refused, saying why")
    func refusesWrittenSpaceOverTaggedColor() throws {
        // Given
        let path = directory.file("mixed.pdf")
        let calibrated = PDFValue.array([.name("CalGray"), .dictionary(["WhitePoint": .array([.real(0.9642), .integer(1), .real(0.8249)])])])
        try PageFile.write(
            [PageFile.page("/C0 cs 0.5 sc 0 0 10 10 re f 1 0 0 rg 0 0 5 5 re f", resources: ["ColorSpace": .dictionary(["C0": calibrated])])],
            to: path
        )
        let file = MediaFile(path: path, page: 1)

        // When
        // Then
        #expect(throws: Never.self) { try sut.check(file, reading: .tagged) }
        #expect(throws: DecoderError.unreadablePage(file: path, page: 1, fault: .untaggedColor(.displayP3))) {
            try sut.check(file, reading: .working(colorSpace: .displayP3, targetPeak: nil))
        }
        #expect(PageFault.untaggedColor(.displayP3).reason.contains("Core Graphics draws DeviceRGB and DeviceGray as sRGB"))
    }

    // MARK: - Private
    private func writeEncrypted(
        to path: String,
        userPassword: String
    ) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        let info: [CFString: Any] = [kCGPDFContextUserPassword: userPassword, kCGPDFContextOwnerPassword: "owner"]
        let context = try #require(CGContext(URL(fileURLWithPath: path) as CFURL, mediaBox: &mediaBox, info as CFDictionary))
        context.beginPDFPage(nil)
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        context.endPDFPage()
        context.closePDF()
    }
}
