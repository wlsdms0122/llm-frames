//
//  QuartzRendererTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import CryptoKit
import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import FramesTestMedia
import Testing

@Suite("QuartzRenderer Tests")
struct QuartzRendererTests {
    // MARK: - Property
    // A 16-bit output reproduces an 8-bit colour to well within one step.
    private let tolerance = 1.0 / 255

    // MARK: - Initializer
    // MARK: - Test
    @Test("the frame is the list's size and filled with its background, premultiplied")
    func fillsBackground() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let list = DisplayList(size: Size(width: 6, height: 4), background: Color(written: "#3366CC80"), seed: 0, items: [])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        #expect(bitmap.width == 6 && bitmap.height == 4 && bitmap.depth == .halfFloat)
        let alpha = 128.0 / 255
        expect(bitmap.pixel(x: 5, y: 3), equals: [0.2 * alpha, 0.4 * alpha, 0.8 * alpha, alpha])
    }

    @Test("opacity composites the item source-over at that alpha")
    func appliesOpacity() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 10, height: 10), color: Color(written: "#FF0000"))
        let list = list(size: 10, items: [DisplayItem(opacity: 0.5, content: .path(fill))])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(bitmap.pixel(x: 5, y: 5), equals: [1, 0.5, 0.5, 1])
    }

    @Test("a mask cuts the item in output pixels")
    func appliesMask() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 10, height: 10), color: Color(written: "#FF0000"))
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0),
            mask: mask(Rectangle(x: 0, y: 0, width: 5, height: 20)),
            content: .path(fill)
        )
        let list = list(size: 20, items: [item])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(bitmap.pixel(x: 2, y: 15), equals: [1, 0, 0, 1])
        expect(bitmap.pixel(x: 7, y: 15), equals: [1, 1, 1, 1])
    }

    @Test("a reveal cuts the item in its own coordinates, so it turns with a rotated item")
    func turnsReveal() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 20, height: 10), color: Color(written: "#FF0000"))
        // A quarter turn clockwise then 30 to the right: (x, y) goes to (30 - y, x).
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 30, ty: 0),
            reveal: Rectangle(x: 0, y: 0, width: 10, height: 10),
            content: .path(fill)
        )
        let list = list(size: 40, items: [item])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(bitmap.pixel(x: 25, y: 5), equals: [1, 0, 0, 1])
        expect(bitmap.pixel(x: 25, y: 15), equals: [1, 1, 1, 1])
    }

    @Test("a nested display list is drawn at its own size and placed by the picture")
    func drawsNestedList() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let half = PathItem(filling: Rectangle(x: 0, y: 0, width: 5, height: 10), color: Color(written: "#FF0000"))
        let nested = DisplayList(
            size: Size(width: 10, height: 10),
            background: Color(written: "#0000FF"),
            seed: 0,
            items: [DisplayItem(content: .path(half))]
        )
        let picture = PictureItem(
            source: .displayList(nested),
            rectangle: nil,
            destination: Rectangle(x: 20, y: 20, width: 20, height: 20)
        )
        let list = list(size: 50, items: [DisplayItem(content: .picture(picture))])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(bitmap.pixel(x: 25, y: 30), equals: [1, 0, 0, 1])
        expect(bitmap.pixel(x: 35, y: 30), equals: [0, 0, 1, 1])
        expect(bitmap.pixel(x: 45, y: 30), equals: [1, 1, 1, 1])
    }

    @Test("an adjustment draws the backdrop inside its mask through its filter, at its opacity")
    func adjustsBackdrop() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 16, height: 16), color: Color(written: "#3399CC"))
        let adjust = DisplayItem(
            opacity: 0.5,
            mask: mask(Rectangle(x: 2, y: 2, width: 8, height: 8)),
            content: .adjust(AdjustItem(filter: [FilterEntry(operations: [.saturation(amount: 0)])]))
        )

        // When
        let bitmap = try sut.frame(of: list(size: 16, items: [DisplayItem(content: .path(fill)), adjust]))

        // Then
        // Saturation 0 turns the backdrop into its Rec. 709 luma, composited over it at half opacity.
        let color = [0.2, 0.6, 0.8]
        let luma = 0.2126 * color[0] + 0.7152 * color[1] + 0.0722 * color[2]
        expect(bitmap.pixel(x: 5, y: 5), equals: color.map { 0.5 * luma + 0.5 * $0 } + [1])
        expect(bitmap.pixel(x: 12, y: 12), equals: color + [1])
    }

    @Test("check accepts every blend mode of FRAMES-11")
    func acceptsBlendModes() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 1, height: 1), color: Color(written: "#FF0000"))
        let items = BlendMode.allCases.map { DisplayItem(blend: $0.rawValue, content: .path(fill)) }

        // When
        let checking = { try sut.check(list(size: 1, items: items)) }

        // Then
        #expect(throws: Never.self) { try checking() }
    }

    @Test(
        "check accepts a list of either compositing and a LUT built for any space",
        arguments: LookUpTableSpace.allCases
    )
    func acceptsColorKeys(space: LookUpTableSpace) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("identity.cube")
        let contents = "LUT_3D_SIZE 2\n" + (0..<8).map { index in
            (0..<3).map { axis in index >> axis & 1 == 1 ? "1" : "0" }.joined(separator: " ")
        }.joined(separator: "\n")
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
        let file = PinnedFile(path: path, sha256: sha256(of: contents))
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let adjust = AdjustItem(filter: [FilterEntry(operations: [.lut(file: file, amount: 1, space: space)])])
        let nested = DisplayList(
            size: Size(width: 1, height: 1),
            background: Color(written: "#00000000"),
            compositing: .linear,
            seed: 0,
            items: [DisplayItem(blend: "add", content: .adjust(adjust))]
        )
        let picture = PictureItem(
            source: .displayList(nested),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 1, height: 1)
        )

        // When
        let checking = { try sut.check(list(size: 1, items: [DisplayItem(content: .picture(picture))])) }

        // Then
        #expect(throws: Never.self) { try checking() }
    }

    @Test("check refuses a blend mode it has no kernel for, naming its place in the nested list")
    func refusesUnknownBlend() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 1, height: 1), color: Color(written: "#FF0000"))
        let nested = list(size: 1, items: [DisplayItem(content: .path(fill)), DisplayItem(blend: "linear-dodge", content: .path(fill))])
        let picture = PictureItem(
            source: .displayList(nested),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 1, height: 1)
        )

        // When
        let checking = { try sut.check(list(size: 1, items: [DisplayItem(content: .picture(picture))])) }

        // Then
        #expect(throws: QuartzError.unsupportedBlend(name: "linear-dodge", place: "items[0].source.items[1].blend")) {
            try checking()
        }
    }

    @Test("check walks a track matte's source, naming its place there")
    func refusesUnknownBlendInTrackMatte() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 1, height: 1), color: Color(written: "#FF0000"))
        let source = list(size: 1, items: [DisplayItem(blend: "linear-dodge", content: .path(fill))])
        let item = DisplayItem(trackMatte: ItemTrackMatte(source: source, mode: .alpha, isInverted: false), content: .path(fill))

        // When
        let checking = { try sut.check(list(size: 1, items: [item])) }

        // Then
        #expect(throws: QuartzError.unsupportedBlend(name: "linear-dodge", place: "items[0].trackMatte.source.items[0].blend")) {
            try checking()
        }
    }

    @Test("check accepts a displace op, whose map the decoder checks and drawing reads")
    func acceptsDisplace() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let map = PinnedFile(path: "/abs/ripple.png", sha256: String(repeating: "a", count: 64))
        let adjust = AdjustItem(filter: [FilterEntry(operations: [
            .exposure(ev: 1),
            .displace(file: map, amount: 4, offset: Point(x: 0, y: 0))
        ])])

        // When
        let checking = { try sut.check(list(size: 1, items: [DisplayItem(content: .adjust(adjust))])) }

        // Then
        #expect(throws: Never.self) { try checking() }
    }

    @Test("check accepts a corner pin on a picture of a nested list, as a clip's group carries it")
    func acceptsCornerPinGroup() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let item = cornerPinned(.none)

        // When
        let checking = { try sut.check(list(size: 4, items: [item])) }

        // Then
        #expect(throws: Never.self) { try checking() }
    }

    // A clip's group carries none of what the picture or item adds here (FRAMES-20 Pictures).
    @Test(
        "check refuses a corner pin on a picture no group draws, naming its place",
        arguments: [CornerPinAddition.media, .filter, .radius, .border, .shadow, .reveal]
    )
    func refusesCornerPinOutsideGroup(addition: CornerPinAddition) throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let nested = list(size: 4, items: [cornerPinned(addition)])
        let picture = PictureItem(
            source: .displayList(nested),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 4, height: 4)
        )

        // When
        let checking = { try sut.check(list(size: 4, items: [DisplayItem(content: .picture(picture))])) }

        // Then
        #expect(throws: QuartzError.unsupportedCornerPin(place: "items[0].source.items[0].cornerPin")) {
            try checking()
        }
    }

    @Test(
        "check refuses a corner pin that is not strictly convex, or four points at [0, 0] outside a sample list, naming its place",
        arguments: [
            (false, Quad.collapsed, "items[0].cornerPin"),
            (true, Quad(Rectangle(x: 1, y: 1, width: 0, height: 0)), "samples[1][0].cornerPin")
        ]
    )
    func refusesNonConvexCornerPin(
        isSampled: Bool,
        cornerPin: Quad,
        place: String
    ) throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let full = Quad(Rectangle(x: 0, y: 0, width: 4, height: 4))
        let checked = isSampled
            ? samplesList(size: 4, samples: [[cornerPinned(full)], [cornerPinned(cornerPin)]])
            : list(size: 4, items: [cornerPinned(cornerPin)])

        // When
        let checking = { try sut.check(checked) }

        // Then
        #expect(throws: QuartzError.nonConvexCornerPin(place: place)) { try checking() }
    }

    @Test("check accepts a group with four points at [0, 0] as its corner pin in a sample list and in a list nested in one")
    func acceptsCollapsedGroupInSample() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let full = Quad(Rectangle(x: 0, y: 0, width: 4, height: 4))
        let nested = PictureItem(
            source: .displayList(list(size: 4, items: [cornerPinned(.collapsed)])),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 4, height: 4)
        )
        let list = samplesList(
            size: 4,
            samples: [[cornerPinned(.collapsed), DisplayItem(content: .picture(nested))], [cornerPinned(full), cornerPinned(full)]]
        )

        // When
        let checking = { try sut.check(list) }

        // Then
        #expect(throws: Never.self) { try checking() }
    }

    @Test("a sample list's group with four points at [0, 0] as its corner pin draws nothing, so the mean is half the other sample's")
    func drawsCollapsedGroupInSample() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let full = Quad(Rectangle(x: 0, y: 0, width: 4, height: 4))
        let list = samplesList(size: 4, background: "#00000000", samples: [[cornerPinned(.collapsed)], [cornerPinned(full)]])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(bitmap.pixel(x: 2, y: 2), equals: [0.5, 0, 0, 0.5])
    }

    @Test("check walks every sample list, naming its place there")
    func refusesUnknownBlendInSample() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 1, height: 1), color: Color(written: "#FF0000"))
        let list = DisplayList(
            size: Size(width: 1, height: 1),
            background: Color(written: "#FFFFFF"),
            seed: 0,
            samples: [[DisplayItem(content: .path(fill))], [DisplayItem(blend: "linear-dodge", content: .path(fill))]]
        )

        // When
        let checking = { try sut.check(list) }

        // Then
        #expect(throws: QuartzError.unsupportedBlend(name: "linear-dodge", place: "samples[1][0].blend")) {
            try checking()
        }
    }

    // Each cube is pinned by its own SHA-256, so only its contents are wrong. `line` is where the reader stops.
    @Test(
        "check refuses a pinned cube that does not read as a 3D LUT, naming its place and the cube's error",
        arguments: [
            ("LUT_1D_SIZE 2\n0 0 0\n1 1 1", 1),
            ("LUT_3D_SIZE 2\n0 0 0\n1 1 1", 3),
            ("LUT_3D_SIZE 2\nLUT_3D_GAMMA 1\n0 0 0", 2),
            ("LUT_3D_SIZE 2\nDOMAIN_MIN 1 1 1\nDOMAIN_MAX 0 0 0\n" + String(repeating: "0 0 0\n", count: 8), 3)
        ]
    )
    func refusesMalformedCube(
        contents: String,
        line: Int
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("broken.cube")
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
        let file = PinnedFile(path: path, sha256: sha256(of: contents))
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let adjust = AdjustItem(filter: [FilterEntry(operations: [.exposure(ev: 1), .lut(file: file, amount: 1)])])
        let nested = list(size: 1, items: [DisplayItem(content: .adjust(adjust))])
        let picture = PictureItem(
            source: .displayList(nested),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 1, height: 1)
        )

        // When
        let error = #expect(throws: QuartzError.self) {
            try sut.check(list(size: 1, items: [DisplayItem(content: .picture(picture))]))
        }

        // Then
        guard case let .unreadableTable(place, .malformedCube(errorFile, errorLine, _)) = error else {
            Issue.record("expected a malformed cube, got \(String(describing: error))")
            return
        }
        #expect(place == "items[0].source.items[0].filter[0].ops[1]")
        #expect(errorFile == path && errorLine == line)
    }

    @Test("a media picture is read as working values in its frame's colour space, tone mapped to its target peak")
    func readsMediaFrameReading() throws {
        // Given
        let decoder = ReadingDecoder()
        let sut = QuartzRenderer(decoder: decoder)
        let media = PinnedMedia(source: .file(PinnedFile(path: "/picture.png", sha256: ""), frameTimes: nil))
        let picture = PictureItem(
            source: .media(MediaFrame(
                media: media,
                index: 0,
                reading: .working(colorSpace: .rec2100HLG, targetPeak: 203)
            )),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 4, height: 4)
        )
        let list = DisplayList(
            size: Size(width: 4, height: 4),
            background: Color(written: "#00000000"),
            seed: 0,
            items: [DisplayItem(content: .picture(picture))]
        )

        // When
        _ = try sut.frame(of: list)

        // Then
        #expect(decoder.readings(of: "/picture.png") == [.working(colorSpace: .rec2100HLG, targetPeak: 203)])
    }

    @Test("a LUT read by check is drawn from the renderer's cache without reading its cube again")
    func drawsCheckedTable() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("invert.cube")
        // The corners of a 2 x 2 x 2 cube, red varying fastest, each mapped to its complement.
        let entries = (0..<8).map { index in
            (0..<3).map { axis in index >> axis & 1 == 1 ? "0" : "1" }.joined(separator: " ")
        }
        let contents = "LUT_3D_SIZE 2\n" + entries.joined(separator: "\n")
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
        let file = PinnedFile(path: path, sha256: sha256(of: contents))
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let adjust = AdjustItem(filter: [FilterEntry(operations: [.lut(file: file, amount: 1)])])
        let list = list(size: 4, items: [DisplayItem(content: .adjust(adjust))])
        try sut.check(list)
        try FileManager.default.removeItem(atPath: path)

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(bitmap.pixel(x: 2, y: 2), equals: [0, 0, 0, 1])
    }

    @Test(
        "a list with samples is the mean of its sample pictures, taken in the form its compositing names",
        arguments: [(Compositing.encoded, 0.5), (.linear, 0.735357)]
    )
    func drawsSampleMean(
        compositing: Compositing,
        mean: Double
    ) throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let samples = ["#FFFFFF", "#000000"].map { color in
            [DisplayItem(content: .path(PathItem(filling: Rectangle(x: 0, y: 0, width: 4, height: 4), color: Color(written: color))))]
        }
        let list = samplesList(size: 4, compositing: compositing, samples: samples)

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(bitmap.pixel(x: 2, y: 2), equals: [mean, mean, mean, 1])
    }

    @Test("sample lists that draw the same picture give that picture back", arguments: [2, 3, 16, 64, 256])
    func returnsEqualPictures(count: Int) throws {
        // Given
        // Each sample's own colour lies under an opaque square, so every sample draws the same picture.
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let samples = (0..<count).map { index in
            let gray = Double(index) / Double(count)
            return [
                DisplayItem(content: .path(PathItem(
                    filling: Rectangle(x: 0, y: 0, width: 6, height: 6),
                    color: Color(written: "color(srgb \(gray) \(gray) \(gray) / 1)")
                ))),
                DisplayItem(content: .path(PathItem(filling: Rectangle(x: 0, y: 0, width: 6, height: 6), color: Color(written: "#FF0000")))),
                DisplayItem(opacity: 0.6, content: .path(PathItem(
                    geometry: .ellipse(Rectangle(x: 0.5, y: 1, width: 4.5, height: 3.7)),
                    fill: .color(Color(written: "#3366CC")),
                    stroke: nil
                )))
            ]
        }
        let picture = try sut.frame(of: list(size: 6, items: samples[0]))

        // When
        let bitmap = try sut.frame(of: samplesList(size: 6, samples: samples))

        // Then
        #expect(components(of: bitmap) == components(of: picture))
    }

    @Test("the mean is the sum of the sample pictures in 32-bit float in sample order, divided once, the same in every run")
    func sumsSamplesInOrder() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let samples = (0..<5).map { index in
            [DisplayItem(
                transform: Frames.AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0.37 * Double(index), ty: 0.21 * Double(index)),
                opacity: 0.8,
                content: .path(PathItem(
                    geometry: .ellipse(Rectangle(x: 1, y: 1, width: 5.3, height: 4.1)),
                    fill: .color(Color(written: "color(srgb 0.9 0.4 0.2 / 0.7)")),
                    stroke: nil
                ))
            )]
        }
        let pictures = try samples.map { try sut.frame(of: list(size: 8, items: $0)) }
        var sums = [Float](repeating: 0, count: 8 * 8 * 4)
        for picture in pictures {
            for (index, half) in halves(of: picture).enumerated() {
                sums[index] += Float(half)
            }
        }
        let expected = sums.map { Float16($0 / Float(samples.count)) }

        // When
        let bitmap = try sut.frame(of: samplesList(size: 8, samples: samples))
        let again = try QuartzRenderer(decoder: AVFoundationDecoder()).frame(of: samplesList(size: 8, samples: samples))

        // Then
        #expect(halves(of: bitmap) == expected)
        #expect(components(of: bitmap) == components(of: again))
    }

    @Test("both sides of a push meet in every sample, so the seam is opaque in their mean")
    func keepsPushSeamOpaque() throws {
        // Given
        // The seam lies at x = 2 + i in sample i, so the pixel at x = 3 is the left side's in two of the four samples.
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let samples = (0..<4).map { index in
            let seam = 2 + Double(index)
            return [
                DisplayItem(content: .path(PathItem(filling: Rectangle(x: 0, y: 0, width: seam, height: 2), color: Color(written: "#FF0000")))),
                DisplayItem(content: .path(PathItem(filling: Rectangle(x: seam, y: 0, width: 8 - seam, height: 2), color: Color(written: "#0000FF"))))
            ]
        }
        let list = samplesList(size: 8, background: "#00000000", samples: samples)

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        #expect((0..<8).allSatisfy { x in bitmap.pixel(x: x, y: 1)[3] == 1 })
        #expect(bitmap.pixel(x: 3, y: 1) == [0.5, 0, 0.5, 1])
    }

    // MARK: - Private
    // A picture of a 4 x 4 list carried onto a trapezoid, with `addition` added to it or its item.
    private func cornerPinned(_ addition: CornerPinAddition) -> DisplayItem {
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 4, height: 4), color: Color(written: "#FF0000"))
        let source: PictureItemSource = addition == .media
            ? .media(MediaFrame(
                media: PinnedMedia(source: .file(PinnedFile(path: "/picture.png", sha256: ""), frameTimes: nil)),
                index: 0
            ))
            : .displayList(list(size: 4, items: [DisplayItem(content: .path(fill))]))
        let picture = PictureItem(
            source: source,
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 4, height: 4),
            filter: addition == .filter ? [FilterEntry(operations: [.exposure(ev: 1)])] : [],
            radius: addition == .radius ? 1 : 0,
            border: addition == .border ? MediaBorder(width: 1, color: Color(written: "#000000")) : nil,
            shadow: addition == .shadow ? DropShadow(radius: 1, offset: Point(x: 1, y: 1), color: Color(written: "#000000")) : nil,
            cornerPin: Quad(
                topLeft: Point(x: 1, y: 0),
                topRight: Point(x: 3, y: 0),
                bottomRight: Point(x: 4, y: 4),
                bottomLeft: Point(x: 0, y: 4)
            )
        )

        return DisplayItem(
            reveal: addition == .reveal ? Rectangle(x: 0, y: 0, width: 2, height: 4) : nil,
            content: .picture(picture)
        )
    }

    // A clip's group: a picture of a 4 x 4 list filled red, carried from [0, 0, 4, 4] onto `cornerPin`.
    private func cornerPinned(_ cornerPin: Quad) -> DisplayItem {
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 4, height: 4), color: Color(written: "#FF0000"))
        let picture = PictureItem(
            source: .displayList(list(size: 4, items: [DisplayItem(content: .path(fill))])),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 4, height: 4),
            cornerPin: cornerPin
        )

        return DisplayItem(content: .picture(picture))
    }

    // One sharp `add` mask of the rectangle in output pixels.
    private func mask(_ rectangle: Rectangle) -> [ItemMask] {
        [ItemMask(geometry: .rect(rectangle, radius: 0), transform: .identity, feather: 0, isInverted: false, mode: .add)]
    }

    private func list(
        size: Double,
        items: [DisplayItem]
    ) -> DisplayList {
        DisplayList(size: Size(width: size, height: size), background: Color(written: "#FFFFFF"), seed: 0, items: items)
    }

    private func samplesList(
        size: Double,
        background: String = "#FFFFFF",
        compositing: Compositing = .encoded,
        samples: [[DisplayItem]]
    ) -> DisplayList {
        DisplayList(
            size: Size(width: size, height: size),
            background: Color(written: background),
            compositing: compositing,
            seed: 0,
            samples: samples
        )
    }

    // Every component of the bitmap, row by row, as its raw sixteen bits.
    private func components(of bitmap: Bitmap) -> [UInt16] {
        (0..<bitmap.height).flatMap { y in (0..<bitmap.width).flatMap { x in bitmap.components(x: x, y: y) } }
    }

    // Every component of a half float bitmap, row by row.
    private func halves(of bitmap: Bitmap) -> [Float16] {
        components(of: bitmap).map(Float16.init(bitPattern:))
    }

    private func sha256(of contents: String) -> String {
        SHA256.hash(data: Data(contents.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func expect(
        _ pixel: [Double],
        equals expected: [Double],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            zip(pixel, expected).allSatisfy { abs($0 - $1) <= tolerance },
            "\(pixel) is not \(expected)",
            sourceLocation: sourceLocation
        )
    }
}

