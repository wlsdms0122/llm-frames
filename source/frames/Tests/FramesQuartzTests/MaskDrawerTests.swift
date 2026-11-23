//
//  MaskDrawerTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/18/26.
//

import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import Testing

@Suite("MaskDrawer Tests")
struct MaskDrawerTests {
    // MARK: - Property
    // A 16-bit output reproduces a mask value to well within one 8-bit step.
    private static let tolerance = 1.0 / 255
    private static let size = 40.0
    private static let lens = PathGeometry.path(
        [
            PathVertex(vertex: Point(x: 4, y: 20), inTangent: Point(x: 10, y: 20), outTangent: Point(x: 10, y: -20)),
            PathVertex(vertex: Point(x: 36, y: 20), inTangent: Point(x: -10, y: -20), outTangent: Point(x: -10, y: 20))
        ],
        isClosed: true
    )

    private let sut = QuartzRenderer(decoder: AVFoundationDecoder())

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a single mask starts from its mode's start value: add from 0, subtract and intersect from 1",
        arguments: [(MaskMode.add, 1.0, 0.0), (.subtract, 0, 1), (.intersect, 1, 0)]
    )
    func startsFromModeValue(
        mode: MaskMode,
        inside: Double,
        outside: Double
    ) throws {
        // Given
        let mask = mask(Rectangle(x: 10, y: 10, width: 20, height: 20), mode: mode)

        // When
        let bitmap = try sut.frame(of: list(masks: [mask]))

        // Then
        expect(alpha(of: bitmap, x: 20, y: 20), equals: inside)
        expect(alpha(of: bitmap, x: 5, y: 5), equals: outside)
        expect(alpha(of: bitmap, x: 35, y: 20), equals: outside)
    }

    @Test("masks combine in list order: an add, then a subtract cutting from it, then an intersect keeping its part")
    func combinesInOrder() throws {
        // Given
        let masks = [
            mask(Rectangle(x: 0, y: 0, width: 30, height: 40), mode: .add),
            mask(Rectangle(x: 10, y: 0, width: 10, height: 40), mode: .subtract),
            mask(Rectangle(x: 0, y: 0, width: 40, height: 20), mode: .intersect)
        ]

        // When
        let bitmap = try sut.frame(of: list(masks: masks))

        // Then
        expect(alpha(of: bitmap, x: 5, y: 5), equals: 1)
        expect(alpha(of: bitmap, x: 15, y: 5), equals: 0)
        expect(alpha(of: bitmap, x: 25, y: 5), equals: 1)
        expect(alpha(of: bitmap, x: 35, y: 5), equals: 0)
        expect(alpha(of: bitmap, x: 5, y: 30), equals: 0)
    }

    @Test("an add mask after a subtract brings back what the subtract cut")
    func addsAfterSubtract() throws {
        // Given
        let masks = [
            mask(Rectangle(x: 10, y: 0, width: 10, height: 40), mode: .subtract),
            mask(Rectangle(x: 0, y: 0, width: 15, height: 40), mode: .add)
        ]

        // When
        let bitmap = try sut.frame(of: list(masks: masks))

        // Then
        expect(alpha(of: bitmap, x: 12, y: 20), equals: 1)
        expect(alpha(of: bitmap, x: 17, y: 20), equals: 0)
        expect(alpha(of: bitmap, x: 30, y: 20), equals: 1)
    }

    @Test("an inverted mask is 0 inside its geometry and 1 outside it, up to the frame's edge")
    func invertsMask() throws {
        // Given
        let mask = mask(Rectangle(x: 10, y: 10, width: 20, height: 20), isInverted: true)

        // When
        let bitmap = try sut.frame(of: list(masks: [mask]))

        // Then
        expect(alpha(of: bitmap, x: 20, y: 20), equals: 0)
        expect(alpha(of: bitmap, x: 5, y: 20), equals: 1)
        expect(alpha(of: bitmap, x: 0, y: 0), equals: 1)
    }

    // The edge is at x = 20.5, so pixel 20's centre lies on it and pixel 16's one standard deviation inside.
    @Test("a feather blurs the edge by a Gaussian whose standard deviation is the feather, and the frame does not cut it")
    func feathersEdge() throws {
        // Given
        let mask = mask(Rectangle(x: -100, y: -100, width: 120.5, height: 240), feather: 4)

        // When
        let bitmap = try sut.frame(of: list(masks: [mask]))

        // Then
        let values = (0..<40).map { alpha(of: bitmap, x: $0, y: 20) }
        expect(values[20], equals: 0.5, within: 0.01)
        expect(values[16], equals: 0.8413, within: 0.01)
        expect(values[24], equals: 0.1587, within: 0.01)
        expect(values[0], equals: 1, within: 0.01)
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 >= $1 - Self.tolerance }, "\(values)")
        #expect(values[18] > values[20] && values[20] > values[22])
    }

    @Test("a mask lands where its transform carries it, turned and scaled")
    func carriesMaskByTransform() throws {
        // Given
        // (x, y) goes to (30 - 2 y, 2 x), so the 10 x 4 rectangle covers x 22 to 30 and y 0 to 20.
        let mask = ItemMask(
            geometry: .rect(Rectangle(x: 0, y: 0, width: 10, height: 4), radius: 0),
            transform: Frames.AffineTransform(a: 0, b: 2, c: -2, d: 0, tx: 30, ty: 0),
            feather: 0,
            isInverted: false,
            mode: .add
        )

        // When
        let bitmap = try sut.frame(of: list(masks: [mask]))

        // Then
        expect(alpha(of: bitmap, x: 26, y: 10), equals: 1)
        expect(alpha(of: bitmap, x: 5, y: 2), equals: 0)
        expect(alpha(of: bitmap, x: 26, y: 25), equals: 0)
        expect(alpha(of: bitmap, x: 18, y: 10), equals: 0)
    }

    @Test("a polyline mask is filled by the nonzero rule, and an ellipse mask leaves its rectangle's corners")
    func fillsPolylineAndEllipse() throws {
        // Given
        let triangle = ItemMask(
            geometry: .polyline([Point(x: 0, y: 0), Point(x: 40, y: 0), Point(x: 0, y: 40)], isClosed: true),
            transform: .identity,
            feather: 0,
            isInverted: false,
            mode: .add
        )
        let ellipse = ItemMask(
            geometry: .ellipse(Rectangle(x: 0, y: 0, width: 40, height: 40)),
            transform: .identity,
            feather: 0,
            isInverted: false,
            mode: .add
        )

        // When
        let cut = try sut.frame(of: list(masks: [triangle]))
        let round = try sut.frame(of: list(masks: [ellipse]))

        // Then
        expect(alpha(of: cut, x: 10, y: 10), equals: 1)
        expect(alpha(of: cut, x: 30, y: 30), equals: 0)
        expect(alpha(of: round, x: 20, y: 20), equals: 1)
        expect(alpha(of: round, x: 2, y: 2), equals: 0)
    }

    // Two vertices at (4, 20) and (36, 20) whose tangents bend the segment there up to y = 5 at x = 20 and the
    // closing segment back down to y = 35, a lens. Its chord alone would enclose nothing.
    @Test("a path mask of two vertices covers the lens its curves enclose, and inverted everything outside it")
    func coversCurvedLens() throws {
        // Given
        let lens = mask(Self.lens)
        let inverted = mask(Self.lens, isInverted: true)

        // When
        let bitmap = try sut.frame(of: list(masks: [lens]))
        let outside = try sut.frame(of: list(masks: [inverted]))

        // Then
        for (x, y) in [(20, 20), (20, 7), (20, 33), (8, 20)] {
            expect(alpha(of: bitmap, x: x, y: y), equals: 1)
            expect(alpha(of: outside, x: x, y: y), equals: 0)
        }
        for (x, y) in [(20, 2), (20, 37), (1, 20), (38, 20), (6, 12)] {
            expect(alpha(of: bitmap, x: x, y: y), equals: 0)
            expect(alpha(of: outside, x: x, y: y), equals: 1)
        }
    }

    // Down the lens's middle column its top edge lies at y = 5. The curve is convex there, so a feather of 3 leaves
    // less than a straight edge would outside it: under 0.0668 at pixel 0, 4.5 out, and about a half at pixel 5.
    @Test("a feather blurs a curved mask's edge, falling off across it")
    func feathersCurvedLens() throws {
        // Given
        let lens = mask(Self.lens, feather: 3)

        // When
        let bitmap = try sut.frame(of: list(masks: [lens]))

        // Then
        let values = (0...20).map { alpha(of: bitmap, x: 20, y: $0) }
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 + Self.tolerance }, "\(values)")
        expect(values[20], equals: 1, within: 0.01)
        #expect(values[0] > 0.005 && values[0] < 0.0668, "\(values[0])")
        #expect(values[5] > 0.3 && values[5] < 0.6, "\(values[5])")
    }

    // MARK: - Private
    // A white fill over the whole frame on a transparent background, so each pixel's alpha is the masks' result.
    private func list(masks: [ItemMask]) -> DisplayList {
        let fill = PathItem(
            filling: Rectangle(x: 0, y: 0, width: Self.size, height: Self.size),
            color: Color(written: "#FFFFFF")
        )

        return DisplayList(
            size: Size(width: Self.size, height: Self.size),
            background: Color(written: "#00000000"),
            seed: 0,
            items: [DisplayItem(mask: masks, content: .path(fill))]
        )
    }

    private func mask(
        _ rectangle: Rectangle,
        feather: Double = 0,
        isInverted: Bool = false,
        mode: MaskMode = .add
    ) -> ItemMask {
        mask(.rect(rectangle, radius: 0), feather: feather, isInverted: isInverted, mode: mode)
    }

    private func mask(
        _ geometry: PathGeometry,
        feather: Double = 0,
        isInverted: Bool = false,
        mode: MaskMode = .add
    ) -> ItemMask {
        ItemMask(
            geometry: geometry,
            transform: .identity,
            feather: feather,
            isInverted: isInverted,
            mode: mode
        )
    }

    private func alpha(
        of bitmap: Bitmap,
        x: Int,
        y: Int
    ) -> Double {
        bitmap.pixel(x: x, y: y)[3]
    }

    private func expect(
        _ value: Double,
        equals expected: Double,
        within tolerance: Double = Self.tolerance,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(abs(value - expected) <= tolerance, "\(value) is not \(expected)", sourceLocation: sourceLocation)
    }
}
