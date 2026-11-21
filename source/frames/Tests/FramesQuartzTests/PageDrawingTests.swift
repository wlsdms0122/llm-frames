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

    @Test(
        "the samples of a frame read one page picture where their scales agree, and each scale its own where a zoom changes it",
        arguments: [
            ([2.01, 2.03, 2.06, 2.1], [4.0]),
            ([1.9, 1.97, 2.03, 2.1], [2.0, 4.0])
        ]
    )
    func asksForPagePerSampleScale(
        stretches: [Double],
        scales: [Double]
    ) throws {
        // Given
        let decoder = ReadingDecoder(pageSize: Size(width: 100, height: 100))
        let sut = QuartzRenderer(decoder: decoder)
        let samples = stretches.map { stretch in
            [DisplayItem(
                transform: Frames.AffineTransform(a: stretch, b: 0, c: 0, d: stretch, tx: 0, ty: 0),
                content: .picture(picture(of: "/abs/deck.pdf", destination: Rectangle(x: 0, y: 0, width: 100, height: 100)))
            )]
        }
        let frame = DisplayList(size: Size(width: 200, height: 200), background: Self.clear, seed: 0, samples: samples)

        // When
        _ = try sut.frame(of: frame)

        // Then
        #expect(decoder.regions(of: "/abs/deck.pdf") == scales.map { scale in
            PageRegionRequest(region: PageRegion(x: 0, y: 0, width: Int(100 * scale), height: Int(100 * scale)), scale: scale)
        })
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

    @Test("a part shown at a scale whose grid positions on the page pass 2^53 is asked for at the largest scale whose positions stay below it")
    func asksForHeldGridPosition() throws {
        // Given
        let decoder = ReadingDecoder(pageSize: Size(width: 4096, height: 4096))
        let sut = QuartzRenderer(decoder: decoder)
        let picture = PictureItem(
            source: .media(frame(of: "/abs/deck.pdf")),
            rectangle: Rectangle(x: 4000, y: 4000, width: 10, height: 10),
            destination: Rectangle(x: 0, y: 0, width: 10, height: 10)
        )
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 0x1p44, b: 0, c: 0, d: 0x1p44, tx: 0, ty: 0),
            content: .picture(picture)
        )

        // When
        _ = try sut.frame(of: list(size: 100, items: [item]))

        // Then
        let requests = decoder.regions(of: "/abs/deck.pdf")
        #expect(requests.map(\.scale) == [0x1p41])
        #expect(requests.allSatisfy { $0.region.x + $0.region.width <= 1 << 53 })
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

    @Test("a filtered page is filtered at the scale it is shown at, its pixelate grid from the destination's top left")
    func filtersPageAtShownScale() throws {
        // Given
        // The square's left and top edges lie 0.3 points into a block of 0.5 points from the page's top left, so that
        // block is 0.4 covered across each edge. Shown at 40 pixels per point from 3.25 points in, block edges fall on
        // output pixels 10, 30 and on to 90.
        let path = directory.file("square.pdf")
        try PageWriter().write(width: 10, height: 10, content: "0 g 3.3 4 2.7 2.7 re f", to: path)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(frame(of: path)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 10, height: 10),
            filter: [FilterEntry(operations: [.pixelate(size: 0.5)])]
        )
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 40, b: 0, c: 0, d: 40, tx: -130, ty: -130),
            content: .picture(picture)
        )

        // When
        let drawn = try sut.frame(of: list(size: 100, items: [item]))

        // Then
        let expected: [(x: Int, y: Int, alpha: Double)] = [
            (5, 5, 0.16), (9, 9, 0.16), (10, 9, 0.4), (9, 10, 0.4), (10, 10, 1), (50, 50, 1), (95, 5, 0.4)
        ]
        for (x, y, alpha) in expected {
            let found = drawn.pixel(x: x, y: y)[3]
            #expect(abs(found - alpha) < 0.02, "(\(x), \(y)): \(found) is not \(alpha)")
        }
    }

    @Test("a matte on a page filtered in part lies over the whole destination")
    func placesMatteOverDestination() throws {
        // Given
        let path = directory.file("white.pdf")
        try PageWriter().write(width: 10, height: 10, content: "1 g 0 0 10 10 re f", to: path)
        let mattePath = directory.file("quadrants.png")
        let levels = [0.0, 96, 128, 160]
        try ImageWriter(size: Size(width: 20, height: 20)).write(to: mattePath) { canvas in
            for (quadrant, level) in levels.enumerated() {
                let rectangle = Rectangle(x: Double(quadrant % 2) * 10, y: Double(quadrant / 2) * 10, width: 10, height: 10)
                canvas.fill(rectangle, red: level, green: level, blue: level)
            }
        }
        let matte = MediaFrame(media: PinnedMedia(source: .file(PinnedFile(path: mattePath, sha256: ""))), index: 0)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(frame(of: path)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 10, height: 10),
            matte: PictureMatte(frame: matte, progress: 0.5, softness: 0.5, isInverted: false)
        )
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 40, b: 0, c: 0, d: 40, tx: -130, ty: -130),
            content: .picture(picture)
        )

        // When
        let drawn = try sut.frame(of: list(size: 100, items: [item]))

        // Then
        // The quadrants meet at 5 points, output pixel 70.
        for (quadrant, level) in levels.enumerated() {
            let x = quadrant % 2 == 0 ? 30 : 90
            let y = quadrant / 2 == 0 ? 30 : 90
            let expected = min(max((0.5 * 1.5 - level / 255) / 0.5, 0), 1)
            let found = drawn.pixel(x: x, y: y)[3]
            #expect(abs(found - expected) < 2.0 / 255, "quadrant \(quadrant): \(found) is not \(expected)")
        }
    }

    @Test("a page matte too large to read whole is asked for only the part that reaches the output")
    func asksForShownPartOfMatte() throws {
        // Given
        let decoder = ReadingDecoder(pageSize: Size(width: 3000, height: 3000))
        let sut = QuartzRenderer(decoder: decoder)
        let picture = PictureItem(
            source: .media(frame(of: "/abs/deck.pdf")),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 50, height: 50),
            matte: PictureMatte(frame: frame(of: "/abs/matte.pdf"), progress: 0.5, softness: 0.5, isInverted: false)
        )
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 120, b: 0, c: 0, d: 120, tx: 0, ty: 0),
            content: .picture(picture)
        )

        // When
        _ = try sut.frame(of: list(size: 100, items: [item]))

        // Then
        // The matte is shown at scale 2 over 100 output pixels, and its resampling reads 3 output pixels past them.
        #expect(decoder.regions(of: "/abs/matte.pdf") == [
            PageRegionRequest(region: PageRegion(x: 0, y: 0, width: 103, height: 103), scale: 2)
        ])
    }

    @Test("a page matte shown through a degenerate map is not read")
    func skipsMatteOfDegenerateMap() throws {
        // Given
        let decoder = ReadingDecoder(pageSize: Size(width: 100, height: 100))
        let sut = QuartzRenderer(decoder: decoder)
        let picture = PictureItem(
            source: .media(frame(of: "/abs/deck.pdf")),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 100, height: 100),
            matte: PictureMatte(frame: frame(of: "/abs/matte.pdf"), progress: 0.5, softness: 0.5, isInverted: false)
        )
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 0, b: 0, c: 0, d: 0, tx: 10, ty: 10),
            content: .picture(picture)
        )

        // When
        _ = try sut.frame(of: list(size: 100, items: [item]))

        // Then
        #expect(decoder.regions(of: "/abs/matte.pdf").isEmpty)
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
