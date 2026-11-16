//
//  QuartzRendererTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
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
        #expect(bitmap.width == 6 && bitmap.height == 4 && bitmap.depth == .sixteen)
        let alpha = 128.0 / 255
        expect(bitmap.pixel(x: 5, y: 3), equals: [0.2 * alpha, 0.4 * alpha, 0.8 * alpha, alpha])
    }

    @Test("a fill covers its rectangle and leaves its hole unfilled")
    func fillsWithHole() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = FillItem(
            rectangle: Rectangle(x: 0, y: 0, width: 20, height: 20),
            color: Color(written: "#FF0000"),
            hole: RoundedRectangle(rectangle: Rectangle(x: 5, y: 5, width: 10, height: 10), radius: 0)
        )
        let list = list(size: 20, items: [DisplayItem(content: .fill(fill))])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(bitmap.pixel(x: 2, y: 2), equals: [1, 0, 0, 1])
        expect(bitmap.pixel(x: 10, y: 10), equals: [1, 1, 1, 1])
        expect(bitmap.pixel(x: 17, y: 12), equals: [1, 0, 0, 1])
    }

    // The outline of (10, 10, 80, 40) is 240 long from its top left corner: the top edge to 80, the right edge's middle
    // at 100, the bottom edge's middle at 160 and the left edge's middle at 220.
    @Test(
        "a stroke is drawn from the top left clockwise as far as its trim",
        arguments: [
            (0.25, [true, false, false, false]),
            (0.5, [true, true, false, false]),
            (1.0, [true, true, true, true])
        ]
    )
    func trimsStroke(trim: Double, inked: [Bool]) throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let stroke = StrokeItem(
            rectangle: Rectangle(x: 10, y: 10, width: 80, height: 40),
            radius: 0,
            width: 4,
            color: Color(written: "#000000"),
            trim: trim
        )
        let list = DisplayList(
            size: Size(width: 100, height: 60),
            background: Color(written: "#00000000"),
            seed: 0,
            items: [DisplayItem(content: .stroke(stroke))]
        )

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        let probes = [(40, 10), (89, 30), (50, 49), (10, 30)]
        let alphas = probes.map { bitmap.pixel(x: $0.0, y: $0.1)[3] }
        #expect(alphas.map { $0 > 0.99 } == inked)
        #expect(alphas.allSatisfy { $0 > 0.99 || $0 < 0.01 })
    }

    @Test("an arrow inks its tail, its shaft and its head up to the tip and nothing past either end")
    func drawsArrow() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let arrow = ArrowItem(
            tail: Point(x: 10, y: 50),
            head: Point(x: 90, y: 50),
            width: 4,
            headSize: 20,
            color: Color(written: "#000000")
        )
        let list = DisplayList(
            size: Size(width: 100, height: 100),
            background: Color(written: "#00000000"),
            seed: 0,
            items: [DisplayItem(content: .arrow(arrow))]
        )

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        // The shaft is 48 to 52 high, and the head 20 wide at its base at x = 70, narrowing to the tip at x = 90.
        let alpha = { (x: Int, y: Int) in bitmap.pixel(x: x, y: y)[3] }
        #expect(alpha(10, 50) > 0.99)
        #expect(alpha(9, 50) < 0.01)
        #expect(alpha(40, 50) > 0.99)
        #expect(alpha(40, 53) < 0.01)
        #expect(alpha(72, 56) > 0.99)
        #expect(alpha(85, 50) > 0.99)
        #expect(alpha(90, 50) < 0.01)
    }

    @Test("opacity composites the item source-over at that alpha")
    func appliesOpacity() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = FillItem(rectangle: Rectangle(x: 0, y: 0, width: 10, height: 10), color: Color(written: "#FF0000"))
        let list = list(size: 10, items: [DisplayItem(opacity: 0.5, content: .fill(fill))])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(bitmap.pixel(x: 5, y: 5), equals: [1, 0.5, 0.5, 1])
    }

    @Test("a mask cuts the item in output pixels")
    func appliesMask() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = FillItem(rectangle: Rectangle(x: 0, y: 0, width: 10, height: 10), color: Color(written: "#FF0000"))
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0),
            mask: Rectangle(x: 0, y: 0, width: 5, height: 20),
            content: .fill(fill)
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
        let fill = FillItem(rectangle: Rectangle(x: 0, y: 0, width: 20, height: 10), color: Color(written: "#FF0000"))
        // A quarter turn clockwise then 30 to the right: (x, y) goes to (30 - y, x).
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 30, ty: 0),
            reveal: Rectangle(x: 0, y: 0, width: 10, height: 10),
            content: .fill(fill)
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
        let half = FillItem(rectangle: Rectangle(x: 0, y: 0, width: 5, height: 10), color: Color(written: "#FF0000"))
        let nested = DisplayList(
            size: Size(width: 10, height: 10),
            background: Color(written: "#0000FF"),
            seed: 0,
            items: [DisplayItem(content: .fill(half))]
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

    @Test("an adjustment through the placeholder filter chain leaves the backdrop as it was")
    func adjustsBackdrop() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = FillItem(rectangle: Rectangle(x: 3, y: 3, width: 9, height: 7), color: Color(written: "#3399CC"))
        let below = [DisplayItem(content: .fill(fill))]
        let adjust = DisplayItem(
            opacity: 0.5,
            content: .adjust(AdjustItem(rectangle: Rectangle(x: 2, y: 2, width: 10, height: 10), filter: [.blur(radius: 2)]))
        )

        // When
        let plain = try sut.frame(of: list(size: 16, items: below))
        let adjusted = try sut.frame(of: list(size: 16, items: below + [adjust]))

        // Then
        #expect(adjusted == plain)
    }

    @Test("check accepts every blend mode of FRAMES-11")
    func acceptsBlendModes() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = FillItem(rectangle: Rectangle(x: 0, y: 0, width: 1, height: 1), color: Color(written: "#FF0000"))
        let items = BlendMode.allCases.map { DisplayItem(blend: $0.rawValue, content: .fill(fill)) }

        // When
        let checking = { try sut.check(list(size: 1, items: items)) }

        // Then
        #expect(throws: Never.self) { try checking() }
    }

    @Test("check refuses a blend mode it has no kernel for, naming its place in the nested list")
    func refusesUnknownBlend() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let fill = FillItem(rectangle: Rectangle(x: 0, y: 0, width: 1, height: 1), color: Color(written: "#FF0000"))
        let nested = list(size: 1, items: [DisplayItem(content: .fill(fill)), DisplayItem(blend: "hue", content: .fill(fill))])
        let picture = PictureItem(
            source: .displayList(nested),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 1, height: 1)
        )

        // When
        let checking = { try sut.check(list(size: 1, items: [DisplayItem(content: .picture(picture))])) }

        // Then
        #expect(throws: QuartzError.unsupportedBlend(name: "hue", place: "items[0].source.items[1].blend")) {
            try checking()
        }
    }

    // MARK: - Private
    private func list(
        size: Double,
        items: [DisplayItem]
    ) -> DisplayList {
        DisplayList(size: Size(width: size, height: size), background: Color(written: "#FFFFFF"), seed: 0, items: items)
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
