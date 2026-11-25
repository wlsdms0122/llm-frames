//
//  PictureDrawerTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import FramesTestMedia
import Testing

@Suite("PictureDrawer Tests")
struct PictureDrawerTests {
    // MARK: - Property
    // Column x of the gradient is grey x * 1000 / 65535.
    private static let step = 1000.0 / 65535
    // A half float has 11 significant bits, so a value from 0.5 to 1 lies 2^-11 from the next one and is held to
    // within 2^-12. The gradient stays below 1.
    private static let halfFloatRounding = 1.0 / 4096

    private let directory: TemporaryDirectory

    // MARK: - Initializer
    init() throws {
        directory = try TemporaryDirectory()
    }

    // MARK: - Test
    @Test("a media picture's region read through the decoder is scaled into its destination")
    func scalesRegionIntoDestination() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try gradient()),
            rectangle: Rectangle(x: 16, y: 0, width: 32, height: 16),
            destination: Rectangle(x: 0, y: 0, width: 16, height: 8)
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 16, height: 8), items: [DisplayItem(content: .picture(picture))]))

        // Then
        // Output column i covers source columns 16 + 2i and 17 + 2i, whose mean is 16.5 + 2i steps. The values are
        // rounded to half floats twice: the source's as the frame's context takes them in, and the resampled result.
        for column in 2..<14 {
            let expected = (16.5 + 2 * Double(column)) * Self.step
            let pixel = bitmap.pixel(x: column, y: 4)
            #expect(
                abs(pixel[0] - expected) <= 8.0 / 65535 + 2 * Self.halfFloatRounding,
                "column \(column): \(pixel[0]) is not \(expected)"
            )
            #expect(pixel[3] == 1)
        }
    }

    @Test("a region the size of its destination at an integer offset is copied pixel for pixel")
    func copiesOneToOne() throws {
        // Given
        let decoder = AVFoundationDecoder()
        let sut = QuartzRenderer(decoder: decoder)
        let frame = try gradient()
        let picture = PictureItem(
            source: .media(frame),
            rectangle: Rectangle(x: 8, y: 0, width: 16, height: 16),
            destination: Rectangle(x: 4, y: 4, width: 16, height: 16)
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 24, height: 24), items: [DisplayItem(content: .picture(picture))]))

        // Then
        let source = try decoder.picture(of: MediaFile(media: frame.media), atFrame: 0)
        expectCopy(bitmap, of: source)
    }

    @Test("a storyline picture at rest copies its media's resampled picture to the output pixel for pixel")
    func copiesStorylinePictureAtRest() throws {
        // Given
        let decoder = AVFoundationDecoder()
        let sut = QuartzRenderer(decoder: decoder)
        let frame = try gradient()
        let media = PictureItem(
            source: .media(frame),
            rectangle: Rectangle(x: 8, y: 0, width: 16, height: 16),
            destination: Rectangle(x: 0, y: 0, width: 16, height: 16)
        )
        let nested = DisplayList(
            size: Size(width: 16, height: 16),
            background: Color(written: "#00000000"),
            seed: 0,
            items: [DisplayItem(content: .picture(media))]
        )
        let content = Rectangle(x: 4, y: 4, width: 16, height: 16)
        let picture = PictureItem(
            source: .displayList(nested),
            rectangle: Rectangle(x: 0, y: 0, width: 16, height: 16),
            destination: content
        )

        // When
        let item = DisplayItem(mask: mask(content), content: .picture(picture))
        let bitmap = try sut.frame(of: list(size: Size(width: 24, height: 24), items: [item]))

        // Then
        let source = try decoder.picture(of: MediaFile(media: frame.media), atFrame: 0)
        expectCopy(bitmap, of: source)
    }

    @Test("a radius leaves the destination's corners transparent")
    func roundsCorners() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try white(size: 40)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 40, height: 40),
            radius: 10
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 40, height: 40), items: [DisplayItem(content: .picture(picture))]))

        // Then
        // Pixel (1, 1) has its centre 12 from the corner arc's centre (10, 10), outside the radius of 10.
        #expect(bitmap.pixel(x: 0, y: 0)[3] == 0)
        #expect(bitmap.pixel(x: 1, y: 1)[3] == 0)
        #expect(bitmap.pixel(x: 38, y: 38)[3] == 0)
        #expect(bitmap.pixel(x: 1, y: 20) == [1, 1, 1, 1])
        #expect(bitmap.pixel(x: 20, y: 20) == [1, 1, 1, 1])
    }

    @Test("a border is drawn inside the destination's edge, over the picture")
    func drawsBorder() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try white(size: 40)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 40, height: 40),
            border: MediaBorder(width: 4, color: Color(written: "#FF0000"))
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 40, height: 40), items: [DisplayItem(content: .picture(picture))]))

        // Then
        #expect(bitmap.pixel(x: 0, y: 20) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 3, y: 20) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 20, y: 39) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 4, y: 20) == [1, 1, 1, 1])
    }

    // A 4 wide red border on a white picture whose destination's left edge lies along x = 10, on a transparent frame:
    // inside it covers x from 10 to 14, centred from 8 to 12 and outside from 6 to 10.
    @Test(
        "a border lies inside, centred on or outside the destination's edge as its align says, over the picture",
        arguments: [
            (StrokeAlign.inside, [nil, nil, nil, true, true, false]),
            (StrokeAlign.center, [nil, nil, true, true, false, false]),
            (StrokeAlign.outside, [nil, true, true, false, false, false])
        ]
    )
    func alignsBorder(
        align: StrokeAlign,
        red: [Bool?]
    ) throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try white(size: 40)),
            rectangle: nil,
            destination: Rectangle(x: 10, y: 10, width: 40, height: 40),
            border: MediaBorder(width: 4, color: Color(written: "#FF0000"), align: align)
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 60, height: 60), items: [DisplayItem(content: .picture(picture))]))

        // Then
        // `nil` is a pixel nothing is drawn on, `true` a red one and `false` a white one.
        for (x, expected) in zip([5, 6, 9, 10, 13, 14], red) {
            let pixel = bitmap.pixel(x: x, y: 30)
            let found: Bool? = switch pixel {
            case [0, 0, 0, 0]: nil
            case [1, 0, 0, 1]: true
            case [1, 1, 1, 1]: false
            default: nil
            }
            #expect(found == expected && (expected != nil || pixel[3] == 0), "pixel (\(x), 30) is \(pixel)")
        }
    }

    // The destination from (10, 10) to (50, 50) has corners of radius 8, its top left one about (18, 18). The 4 wide
    // border outside it reaches 12 from there: pixel (11, 11) lies from 8.5 to 9.9 from it, outside the picture and
    // inside the border, and pixel (7, 7) past 14.
    @Test("a border outside the destination follows its corners rounded by the radius plus the border's width")
    func roundsOutsideBorder() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try white(size: 40)),
            rectangle: nil,
            destination: Rectangle(x: 10, y: 10, width: 40, height: 40),
            radius: 8,
            border: MediaBorder(width: 4, color: Color(written: "#FF0000"), align: .outside)
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 60, height: 60), items: [DisplayItem(content: .picture(picture))]))

        // Then
        #expect(bitmap.pixel(x: 11, y: 11) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 7, y: 7)[3] == 0)
        #expect(bitmap.pixel(x: 7, y: 30) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 14, y: 14) == [1, 1, 1, 1])
    }

    @Test("a filtered picture's border outside its destination is drawn past the part of the picture it filters")
    func drawsOutsideBorderOfFilteredPicture() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try checker(size: 16)),
            rectangle: nil,
            destination: Rectangle(x: 8, y: 8, width: 16, height: 16),
            filter: [FilterEntry(operations: [.lut(file: try darkenedMiddle(), amount: 1)])],
            border: MediaBorder(width: 2, color: Color(written: "#FF0000"), align: .outside)
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 32, height: 32), items: [DisplayItem(content: .picture(picture))]))

        // Then
        #expect(bitmap.pixel(x: 6, y: 16) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 16, y: 25) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 5, y: 16)[3] == 0)
        #expect(bitmap.pixel(x: 8, y: 16)[1] == bitmap.pixel(x: 8, y: 16)[0])
    }

    @Test("the border of a picture whose region starts off the media's origin at another scale lies on the destination's edge")
    func drawsBorderOfOffsetRegion() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try white(size: 40)),
            rectangle: Rectangle(x: 10, y: 20, width: 20, height: 20),
            destination: Rectangle(x: 0, y: 0, width: 40, height: 40),
            border: MediaBorder(width: 4, color: Color(written: "#FF0000"))
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 40, height: 40), items: [DisplayItem(content: .picture(picture))]))

        // Then
        #expect(bitmap.pixel(x: 0, y: 20) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 3, y: 20) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 20, y: 0) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 20, y: 39) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 39, y: 20) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 4, y: 20) == [1, 1, 1, 1])
        #expect(bitmap.pixel(x: 20, y: 20) == [1, 1, 1, 1])
    }

    @Test("a shadow is the picture's shape blurred with its radius as standard deviation and moved by its offset")
    func castsShadow() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try white(size: 10)),
            rectangle: nil,
            destination: Rectangle(x: 45, y: 45, width: 10, height: 10),
            shadow: DropShadow(radius: 3, offset: Point(x: 30, y: 20), color: Color(written: "#000000"))
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 120, height: 120), items: [DisplayItem(content: .picture(picture))]))

        // Then
        // Right of x = 62 lies only the shadow: the box (75, 65, 10, 10) blurred, its alpha centred on (80, 70) with
        // a variance across of 10² / 12 + 3² from the box and the blur.
        var total = 0.0
        var sumX = 0.0
        var sumY = 0.0
        var sumXX = 0.0
        for y in 0..<120 {
            for x in 62..<120 {
                let alpha = bitmap.pixel(x: x, y: y)[3]
                let centerX = Double(x) + 0.5
                total += alpha
                sumX += alpha * centerX
                sumY += alpha * (Double(y) + 0.5)
                sumXX += alpha * centerX * centerX
            }
        }
        let meanX = sumX / total
        let meanY = sumY / total
        let variance = sumXX / total - meanX * meanX
        #expect(abs(meanX - 80) < 0.25)
        #expect(abs(meanY - 70) < 0.25)
        #expect(abs(variance - (100.0 / 12 + 9)) < 1)
        #expect(bitmap.pixel(x: 50, y: 50) == [1, 1, 1, 1])
    }

    @Test("a filtered picture shown at half its size is filtered at that scale, so a nonlinear op sees its detail averaged")
    func filtersAtShownScale() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try checker(size: 16)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 16, height: 16),
            filter: [FilterEntry(operations: [.lut(file: try darkenedMiddle(), amount: 1)])]
        )
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 0, ty: 0),
            content: .picture(picture)
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 8, height: 8), items: [item]))

        // Then
        // Each output pixel averages two black and two white source pixels to 0.5, which the table maps to 0.1.
        for y in 1..<7 {
            for x in 1..<7 {
                let pixel = bitmap.pixel(x: x, y: y)
                #expect(abs(pixel[0] - 0.1) < 0.02, "(\(x), \(y)): \(pixel[0]) is not 0.1")
            }
        }
    }

    @Test("a filtered picture larger than the frame and shown larger than its destination is filtered at its shown scale")
    func filtersShownPartAtShownScale() throws {
        // Given
        // The destination holds two source pixels per unit and is shown at two pixels per unit, so the shown part is
        // filtered pixel for pixel.
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try checker(size: 128)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 64, height: 64),
            filter: [FilterEntry(operations: [.lut(file: try darkenedMiddle(), amount: 1)])]
        )
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0),
            content: .picture(picture)
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 16, height: 16), items: [item]))

        // Then
        for y in 0..<16 {
            for x in 0..<16 {
                let expected = (x + y) % 2 == 0 ? 0.0 : 1
                let pixel = bitmap.pixel(x: x, y: y)
                #expect(abs(pixel[0] - expected) < 0.02, "(\(x), \(y)): \(pixel[0]) is not \(expected)")
            }
        }
    }

    @Test("a filtered picture whose shown part needs more than the pixel limit is filtered at the largest scale it allows")
    func holdsFilteredPictureToPixelLimit() throws {
        // Given
        // Shown at 2 across and 0.25 down, the 16 x 16 frame shows 8 x 64 units of the destination, which need 2048
        // pixels at the larger axis scale and twice the frame's 256 allows 512, so it is filtered at one pixel a unit:
        // each pixel averages two black and two white source pixels to 0.5, which the table maps to 0.1.
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let picture = PictureItem(
            source: .media(try checker(size: 128)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 64, height: 64),
            filter: [FilterEntry(operations: [.lut(file: try darkenedMiddle(), amount: 1)])]
        )
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 2, b: 0, c: 0, d: 0.25, tx: 0, ty: 0),
            content: .picture(picture)
        )

        // When
        let bitmap = try sut.frame(of: list(size: Size(width: 16, height: 16), items: [item]))

        // Then
        for y in 1..<15 {
            for x in 1..<15 {
                let pixel = bitmap.pixel(x: x, y: y)
                #expect(abs(pixel[0] - 0.1) < 0.02, "(\(x), \(y)): \(pixel[0]) is not 0.1")
            }
        }
    }

    // MARK: - Private
    // One sharp `add` mask of the rectangle in output pixels.
    private func mask(_ rectangle: Rectangle) -> [ItemMask] {
        [ItemMask(geometry: .rect(rectangle, radius: 0), transform: .identity, feather: 0, isInverted: false, mode: .add)]
    }

    private func list(
        size: Size,
        items: [DisplayItem]
    ) -> DisplayList {
        DisplayList(size: size, background: Color(written: "#00000000"), seed: 0, items: items)
    }

    // A 64 x 16 sixteen bit grey gradient across.
    private func gradient() throws -> MediaFrame {
        let path = directory.file("gradient.png")
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        try ImageWriter(size: Size(width: 64, height: 16), bitsPerComponent: 16).write(to: path) { canvas in
            for column in 0..<64 {
                let level = Double(column) * Self.step
                canvas.context.setFillColor(CGColor(colorSpace: colorSpace, components: [level, level, level, 1])!)
                canvas.context.fill(CGRect(x: column, y: 0, width: 1, height: 16))
            }
        }

        return frame(at: path)
    }

    private func white(size: Double) throws -> MediaFrame {
        let path = directory.file("white-\(Int(size)).png")
        try ImageWriter(size: Size(width: size, height: size)).write(to: path) { canvas in
            canvas.fill(red: 255, green: 255, blue: 255)
        }

        return frame(at: path)
    }

    // A `size` x `size` checker of single black and white pixels, black at the top left.
    private func checker(size: Int) throws -> MediaFrame {
        let path = directory.file("checker-\(size).png")
        try ImageWriter(size: Size(width: Double(size), height: Double(size))).write(to: path) { canvas in
            canvas.fill(red: 255, green: 255, blue: 255)
            for y in 0..<size {
                for x in 0..<size where (x + y) % 2 == 0 {
                    canvas.fill(Rectangle(x: Double(x), y: Double(y), width: 1, height: 1), red: 0, green: 0, blue: 0)
                }
            }
        }

        return frame(at: path)
    }

    // A 3 x 3 x 3 cube that keeps 0 and 1 on each channel and maps 0.5 to 0.1.
    private func darkenedMiddle() throws -> PinnedFile {
        let levels = [0.0, 0.1, 1]
        let path = directory.file("darkened-middle.cube")
        let entries = (0..<27).map { index in
            "\(levels[index % 3]) \(levels[index / 3 % 3]) \(levels[index / 9])"
        }
        try ("LUT_3D_SIZE 3\n" + entries.joined(separator: "\n")).write(toFile: path, atomically: true, encoding: .utf8)

        return PinnedFile(path: path, sha256: UUID().uuidString)
    }

    private func frame(at path: String) -> MediaFrame {
        MediaFrame(media: PinnedMedia(source: .file(PinnedFile(path: path, sha256: ""), frameTimes: nil)), index: 0)
    }

    // The 16 x 16 output at (4, 4) holds source columns 8 to 23, each value the nearest half float to the source's,
    // and nothing else is drawn.
    private func expectCopy(
        _ bitmap: Bitmap,
        of source: Bitmap,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for y in 0..<16 {
            for x in 0..<16 where bitmap.pixel(x: x + 4, y: y + 4) != halfFloats(of: source.pixel(x: x + 8, y: y)) {
                Issue.record("pixel (\(x + 4), \(y + 4)) is not source pixel (\(x + 8), \(y))", sourceLocation: sourceLocation)
                return
            }
        }
        #expect(bitmap.pixel(x: 2, y: 10)[3] == 0, sourceLocation: sourceLocation)
        #expect(bitmap.pixel(x: 21, y: 10)[3] == 0, sourceLocation: sourceLocation)
    }

    private func halfFloats(of pixel: [Double]) -> [Double] {
        pixel.map { Double(Float16($0)) }
    }
}
