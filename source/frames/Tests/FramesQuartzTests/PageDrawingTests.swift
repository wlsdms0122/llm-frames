//
//  PageDrawingTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import FramesTestMedia
import Testing

@Suite("Page drawing Tests")
struct PageDrawingTests {
    // MARK: - Property
    private static let clear = Color(written: "#00000000")
    private static let black = Color(written: "#000000")

    private let directory: TemporaryDirectory

    // MARK: - Initializer
    init() throws {
        directory = try TemporaryDirectory()
    }

    // MARK: - Test
    @Test("a page is asked for whole at the scale it is shown at, rounded up to a power of two")
    func asksForWholePageAtShownScale() throws {
        // Given
        let decoder = ReadingDecoder(pageSize: Size(width: 100, height: 50))
        let sut = QuartzRenderer(decoder: decoder)
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 3, b: 0, c: 0, d: 2, tx: 0, ty: 0),
            content: .picture(picture(of: "/abs/deck.pdf", destination: Rectangle(x: 0, y: 0, width: 100, height: 50)))
        )

        // When
        _ = try sut.frame(of: list(size: 300, items: [item]))

        // Then
        #expect(decoder.regions(of: "/abs/deck.pdf") == [
            PageRegionRequest(region: PageRegion(x: 0, y: 0, width: 400, height: 200), scale: 4)
        ])
    }

    @Test("a pan at one scale asks for the one whole page in every frame, whatever its offset")
    func asksForSamePictureAcrossPan() throws {
        // Given
        let decoder = ReadingDecoder(pageSize: Size(width: 100, height: 100))
        let sut = QuartzRenderer(decoder: decoder)
        let frames = [0.0, 0.3, 5.7, -41.25].map { offset in
            list(size: 200, items: [DisplayItem(
                transform: Frames.AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: offset, ty: offset / 2),
                content: .picture(picture(of: "/abs/deck.pdf", destination: Rectangle(x: 0, y: 0, width: 100, height: 100)))
            )])
        }

        // When
        for frame in frames.reversed() {
            _ = try sut.frame(of: frame)
        }

        // Then
        #expect(decoder.regions(of: "/abs/deck.pdf") == [
            PageRegionRequest(region: PageRegion(x: 0, y: 0, width: 200, height: 200), scale: 2)
        ])
    }

    @Test("a page too large to read whole is asked for only the part of its rect that reaches the output")
    func asksForShownPartOfRect() throws {
        // Given
        let decoder = ReadingDecoder(pageSize: Size(width: 3000, height: 3000))
        let sut = QuartzRenderer(decoder: decoder)
        let picture = PictureItem(
            source: .media(frame(of: "/abs/deck.pdf")),
            rectangle: Rectangle(x: 100, y: 100, width: 50, height: 50),
            destination: Rectangle(x: 0, y: 0, width: 50, height: 50)
        )
        let item = DisplayItem(transform: Frames.AffineTransform(a: 4, b: 0, c: 0, d: 4, tx: 0, ty: 0), content: .picture(picture))

        // When
        _ = try sut.frame(of: list(size: 100, items: [item]))

        // Then
        #expect(decoder.regions(of: "/abs/deck.pdf") == [
            PageRegionRequest(region: PageRegion(x: 400, y: 400, width: 100, height: 100), scale: 4)
        ])
    }

    @Test("a part larger than the decoder holds is asked for at the largest scale at which the decoder holds it")
    func asksForHeldScale() throws {
        // Given
        let decoder = ReadingDecoder(pageSize: Size(width: 100, height: 80), largestPictureSide: 64)
        let sut = QuartzRenderer(decoder: decoder)
        let item = DisplayItem(
            content: .picture(picture(of: "/abs/deck.pdf", destination: Rectangle(x: 0, y: 0, width: 100, height: 80)))
        )

        // When
        _ = try sut.frame(of: list(size: 100, items: [item]))

        // Then
        #expect(decoder.regions(of: "/abs/deck.pdf") == [
            PageRegionRequest(region: PageRegion(x: 0, y: 0, width: 64, height: 52), scale: 0.64)
        ])
    }

    @Test("a page shown at ten times its size has edges as sharp as a path drawn there")
    func drawsZoomedPageSharp() throws {
        // Given
        let path = directory.file("square.pdf")
        try PageWriter().write(width: 10, height: 10, content: "0 g 2 2 6 6 re f", to: path)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let zoom = Frames.AffineTransform(a: 10, b: 0, c: 0, d: 10, tx: 0, ty: 0)
        let page = DisplayItem(
            transform: zoom,
            content: .picture(picture(of: path, destination: Rectangle(x: 0, y: 0, width: 10, height: 10)))
        )
        let square = DisplayItem(
            content: .path(PathItem(filling: Rectangle(x: 20, y: 20, width: 60, height: 60), color: Self.black))
        )

        // When
        let drawn = try sut.frame(of: list(size: 100, items: [page]))
        let inPlace = try sut.frame(of: list(size: 100, items: [square]))

        // Then
        #expect(largestAlphaDifference(drawn, inPlace, size: 100) < 0.05)
    }

    @Test("what of a page lies outside its rect is cut off before a blur reads it")
    func discardsOutsideRectBeforeFilter() throws {
        // Given
        let path = directory.file("half.pdf")
        try PageWriter().write(width: 20, height: 10, content: "0 g 0 0 10 10 re f", to: path)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(frame(of: path)),
            rectangle: Rectangle(x: 10, y: 0, width: 10, height: 10),
            destination: Rectangle(x: 0, y: 0, width: 10, height: 10),
            filter: [FilterEntry(operations: [.blur(radius: 2)])]
        )
        let item = DisplayItem(transform: Frames.AffineTransform(a: 4, b: 0, c: 0, d: 4, tx: 0, ty: 0), content: .picture(picture))

        // When
        let drawn = try sut.frame(of: list(size: 40, items: [item]))

        // Then
        let alphas = (0..<40).flatMap { y in (0..<40).map { x in drawn.pixel(x: x, y: y)[3] } }
        #expect(alphas.max() ?? 1 < 0.001)
    }

    // MARK: - Private
    private func frame(of path: String) -> MediaFrame {
        MediaFrame(media: PinnedMedia(source: .page(PinnedFile(path: path, sha256: ""), page: 1)), index: 0)
    }

    private func picture(
        of path: String,
        destination: Rectangle
    ) -> PictureItem {
        PictureItem(source: .media(frame(of: path)), rectangle: nil, destination: destination)
    }

    private func list(
        size: Double,
        items: [DisplayItem]
    ) -> DisplayList {
        DisplayList(size: Size(width: size, height: size), background: Self.clear, seed: 0, items: items)
    }

    private func largestAlphaDifference(
        _ first: Bitmap,
        _ second: Bitmap,
        size: Int
    ) -> Double {
        (0..<size).flatMap { y in
            (0..<size).map { x in abs(first.pixel(x: x, y: y)[3] - second.pixel(x: x, y: y)[3]) }
        }
        .max() ?? 0
    }
}
