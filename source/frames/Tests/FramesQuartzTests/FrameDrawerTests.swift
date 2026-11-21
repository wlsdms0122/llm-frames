//
//  FrameDrawerTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/18/26.
//

import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import Testing

@Suite("FrameDrawer Tests")
struct FrameDrawerTests {
    // MARK: - Property
    private static let white = Color(written: "#FFFFFF")
    private static let black = Color(written: "#000000")

    private let sut = QuartzRenderer(decoder: AVFoundationDecoder())

    // MARK: - Initializer
    // MARK: - Test
    @Test("a path's shadow is its alpha blurred in output pixels and moved in its own coordinates, carried by its transform, below it")
    func castsPathShadow() throws {
        // Given
        // At scale 2 the square is (45, 45, 10, 10) on the output and its shadow's offset (30, 20).
        let path = PathItem(
            geometry: .rect(Rectangle(x: 22.5, y: 22.5, width: 5, height: 5), radius: 0),
            fill: .color(Self.white),
            stroke: nil,
            shadow: DropShadow(radius: 3, offset: Point(x: 15, y: 10), color: Self.black)
        )
        let item = DisplayItem(transform: AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0), content: .path(path))

        // When
        let bitmap = try sut.frame(of: list(size: 120, background: "#00000000", items: [item]))

        // Then
        // Right of x = 62 lies only the shadow: the box (75, 65, 10, 10) blurred, its alpha centred on (80, 70) with a
        // variance across of 10² / 12 + 3² from the box and the blur.
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
        #expect(abs(meanX - 80) < 0.25)
        #expect(abs(meanY - 70) < 0.25)
        #expect(abs(sumXX / total - meanX * meanX - (100.0 / 12 + 9)) < 1)
        #expect(bitmap.pixel(x: 50, y: 50) == [1, 1, 1, 1])
    }

    @Test("an item and its shadow take the item's opacity together, so the shadow does not show through the item")
    func fadesItemWithShadow() throws {
        // Given
        let path = PathItem(
            geometry: .rect(Rectangle(x: 10, y: 10, width: 20, height: 20), radius: 0),
            fill: .color(Self.white),
            stroke: nil,
            shadow: DropShadow(radius: 0, offset: Point(x: 4, y: 4), color: Self.black)
        )
        let item = DisplayItem(opacity: 0.5, content: .path(path))

        // When
        let bitmap = try sut.frame(of: list(size: 40, background: "#FF0000", items: [item]))

        // Then
        expect(bitmap.pixel(x: 20, y: 20), equals: [1, 0.5, 0.5, 1])
        expect(bitmap.pixel(x: 32, y: 32), equals: [0.5, 0, 0, 1])
        expect(bitmap.pixel(x: 36, y: 36), equals: [1, 0, 0, 1])
    }

    @Test("a shadow is cast by what the item's reveal shows, and from outside the frame into it")
    func castsRevealedShadow() throws {
        // Given
        // The left half of the bar is revealed, and the square left of the frame casts its shadow 40 to the right.
        let bar = DisplayItem(
            reveal: Rectangle(x: 10, y: 10, width: 20, height: 10),
            content: .path(PathItem(
                geometry: .rect(Rectangle(x: 10, y: 10, width: 40, height: 10), radius: 0),
                fill: .color(Self.white),
                stroke: nil,
                shadow: DropShadow(radius: 0, offset: Point(x: 0, y: 20), color: Self.black)
            ))
        )
        let outside = DisplayItem(content: .path(PathItem(
            geometry: .rect(Rectangle(x: -30, y: 50, width: 20, height: 10), radius: 0),
            fill: .color(Self.white),
            stroke: nil,
            shadow: DropShadow(radius: 0, offset: Point(x: 40, y: 0), color: Self.black)
        )))

        // When
        let bitmap = try sut.frame(of: list(size: 60, background: "#00000000", items: [bar, outside]))

        // Then
        expect(bitmap.pixel(x: 20, y: 35), equals: [0, 0, 0, 1])
        expect(bitmap.pixel(x: 40, y: 35), equals: [0, 0, 0, 0])
        expect(bitmap.pixel(x: 40, y: 15), equals: [0, 0, 0, 0])
        expect(bitmap.pixel(x: 20, y: 55), equals: [0, 0, 0, 1])
    }

    @Test("a masked item casts its shadow from the cut picture, and the mask does not cut the shadow")
    func castsMaskedShadow() throws {
        // Given
        // The mask keeps the left half of the square, x 10 to 20, which casts its shadow 10 to the right, outside the
        // mask. The right half it removes would have cast one at x 30 to 40.
        let item = DisplayItem(
            mask: [ItemMask(
                geometry: .rect(Rectangle(x: 0, y: 0, width: 20, height: 50), radius: 0),
                transform: .identity,
                feather: 0,
                isInverted: false,
                mode: .add
            )],
            content: .path(PathItem(
                geometry: .rect(Rectangle(x: 10, y: 10, width: 20, height: 20), radius: 0),
                fill: .color(Self.white),
                stroke: nil,
                shadow: DropShadow(radius: 0, offset: Point(x: 10, y: 0), color: Self.black)
            ))
        )

        // When
        let bitmap = try sut.frame(of: list(size: 50, background: "#00000000", items: [item]))

        // Then
        expect(bitmap.pixel(x: 15, y: 20), equals: [1, 1, 1, 1])
        expect(bitmap.pixel(x: 25, y: 20), equals: [0, 0, 0, 1])
        expect(bitmap.pixel(x: 35, y: 20), equals: [0, 0, 0, 0])
        expect(bitmap.pixel(x: 15, y: 35), equals: [0, 0, 0, 0])
    }

    @Test("an item's opacity and its mask multiply its alpha once each")
    func multipliesOpacityByMask() throws {
        // Given
        // The feathered edge lies on pixel 20's centre, where the mask is 0.5.
        let item = DisplayItem(
            opacity: 0.5,
            mask: [ItemMask(
                geometry: .rect(Rectangle(x: -100, y: -100, width: 120.5, height: 240), radius: 0),
                transform: .identity,
                feather: 2,
                isInverted: false,
                mode: .add
            )],
            content: .path(PathItem(filling: Rectangle(x: 0, y: 0, width: 40, height: 40), color: Self.white))
        )

        // When
        let bitmap = try sut.frame(of: list(size: 40, background: "#00000000", items: [item]))

        // Then
        #expect(abs(bitmap.pixel(x: 20, y: 20)[3] - 0.25) < 0.01)
        expect(bitmap.pixel(x: 5, y: 20), equals: [0.5, 0.5, 0.5, 0.5])
        expect(bitmap.pixel(x: 35, y: 20), equals: [0, 0, 0, 0])
    }

    @Test("a masked item drawn with a blend mode is cut by its mask before it is blended")
    func masksBlendedItem() throws {
        // Given
        let item = DisplayItem(
            blend: "multiply",
            mask: [ItemMask(
                geometry: .rect(Rectangle(x: 0, y: 0, width: 20, height: 40), radius: 0),
                transform: .identity,
                feather: 0,
                isInverted: false,
                mode: .add
            )],
            content: .path(PathItem(filling: Rectangle(x: 0, y: 0, width: 40, height: 40), color: Self.black))
        )

        // When
        let bitmap = try sut.frame(of: list(size: 40, background: "#FF0000", items: [item]))

        // Then
        expect(bitmap.pixel(x: 10, y: 20), equals: [0, 0, 0, 1])
        expect(bitmap.pixel(x: 30, y: 20), equals: [1, 0, 0, 1])
    }

    @Test(
        "a reveal whose rectangle holds everything the item draws draws it exactly as no reveal",
        arguments: [0, 1, 2, 3, 4]
    )
    func drawsWholeRevealAsNone(index: Int) throws {
        // Given
        let (item, reveal) = Self.wholeReveals[index]
        let revealed = DisplayItem(
            transform: item.transform,
            opacity: item.opacity,
            reveal: reveal,
            content: item.content
        )
        let behind = DisplayItem(content: .path(PathItem(filling: Rectangle(x: 10, y: 50, width: 100, height: 20), color: Self.black)))

        // When
        let without = try sut.frame(of: list(size: 120, background: "#808080", items: [behind, item]))
        let with = try sut.frame(of: list(size: 120, background: "#808080", items: [behind, revealed]))

        // Then
        #expect(without == with)
    }

    // MARK: - Private
    // Items whose edges cross pixels, each with a rectangle that holds everything it draws: a turned path filled and
    // stroked, a turned path with a shadow, a turned picture of a nested list, an adjustment over the whole frame, and a
    // turned adjustment, whose transform carries its reveal only, with the list's frame carried back to its coordinates.
    private static let wholeReveals: [(DisplayItem, Rectangle)] = {
        let turn = AffineTransform(a: 0.866, b: 0.5, c: -0.5, d: 0.866, tx: 60.3, ty: 20.7)
        let stroked = PathItem(
            geometry: .ellipse(Rectangle(x: 0.4, y: 0.2, width: 50.3, height: 30.1)),
            fill: .color(Color(written: "#FF0000")),
            stroke: PathStroke(width: 3, paint: .color(Self.white), join: .round, cap: .round, start: .none, end: .none)
        )
        let shadowed = PathItem(
            geometry: .rect(Rectangle(x: 0.4, y: 0.2, width: 50.3, height: 30.1), radius: 4),
            fill: .color(Color(written: "#00FF00")),
            stroke: nil,
            shadow: DropShadow(radius: 2, offset: Point(x: 3, y: 4), color: Self.black)
        )
        let nested = DisplayList(
            size: Size(width: 40, height: 20),
            background: Color(written: "#0000FF"),
            seed: 0,
            items: [DisplayItem(content: .path(PathItem(filling: Rectangle(x: 5, y: 5, width: 10, height: 10), color: Self.white)))]
        )
        let destination = Rectangle(x: 0.3, y: 0.6, width: 40.2, height: 20.3)
        let picture = PictureItem(source: .displayList(nested), rectangle: Rectangle(x: 0, y: 0, width: 40, height: 20), destination: destination)
        let adjust = AdjustItem(filter: [FilterEntry(operations: [.exposure(ev: 1)])])
        let frame = Rectangle(x: 0, y: 0, width: 120, height: 120)
        let carried = adjust.drawnBounds(carriedBy: turn, over: frame) ?? Rectangle(x: 0, y: 0, width: 0, height: 0)

        return [
            (DisplayItem(transform: turn, content: .path(stroked)), stroked.drawnBounds(carriedBy: turn)),
            (DisplayItem(transform: turn, content: .path(shadowed)), shadowed.drawnBounds(carriedBy: turn)),
            (DisplayItem(transform: turn, opacity: 0.5, content: .picture(picture)), destination),
            (DisplayItem(content: .adjust(adjust)), frame),
            (DisplayItem(transform: turn, content: .adjust(adjust)), carried)
        ]
    }()

    private func list(
        size: Double,
        background: String,
        items: [DisplayItem]
    ) -> DisplayList {
        DisplayList(size: Size(width: size, height: size), background: Color(written: background), seed: 0, items: items)
    }

    private func expect(
        _ pixel: [Double],
        equals expected: [Double],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            zip(pixel, expected).allSatisfy { abs($0 - $1) <= 1.0 / 255 },
            "\(pixel) is not \(expected)",
            sourceLocation: sourceLocation
        )
    }
}
