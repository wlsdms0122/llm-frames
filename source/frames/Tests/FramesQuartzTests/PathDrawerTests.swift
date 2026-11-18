//
//  PathDrawerTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/18/26.
//

import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import Testing

// Paths drawn in black on a transparent 100 x 100 frame, read back by the alpha of whole pixels: a pixel is inked when
// its alpha is above 0.99 and blank when below 0.01. Each probe is a pixel wholly inside or wholly outside what it
// tests, so edge smoothing does not decide it.
@Suite("PathDrawer Tests")
struct PathDrawerTests {
    // MARK: - Property
    private static let black = Color(written: "#000000")

    private let sut = QuartzRenderer(decoder: AVFoundationDecoder())

    // MARK: - Initializer
    // MARK: - Test
    @Test("a self-crossing polyline is filled by the nonzero rule, so its doubly wound middle is filled")
    func fillsByNonzeroRule() throws {
        // Given
        // A five-pointed star drawn through every second point: its middle pentagon is wound twice.
        let points = (0..<5).map { index in
            let angle = (-90 + 144 * Double(index)) * .pi / 180
            return Point(x: 50 + 40 * cos(angle), y: 50 + 40 * sin(angle))
        }
        let path = PathItem(geometry: .polyline(points, isClosed: true), fill: Self.black, stroke: nil)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        #expect(alpha(bitmap, 50, 50) > 0.99)
        #expect(alpha(bitmap, 50, 16) > 0.99)
        #expect(alpha(bitmap, 5, 5) < 0.01)
    }

    @Test("an open polyline is filled as if a straight segment closed it from its last point to its first")
    func fillsOpenPolylineClosed() throws {
        // Given
        let points = [Point(x: 10, y: 10), Point(x: 90, y: 10), Point(x: 10, y: 90)]
        let path = PathItem(geometry: .polyline(points, isClosed: false), fill: Self.black, stroke: nil)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        #expect(alpha(bitmap, 30, 30) > 0.99)
        #expect(alpha(bitmap, 70, 70) < 0.01)
    }

    // A 20 wide stroke turning a right corner at (50, 50): the miter fills the outer square up to (60, 40), the round
    // join the quarter circle of radius 10 about the corner, and the bevel the triangle cut by the line from (50, 40)
    // to (60, 50).
    @Test(
        "each join shapes the outside of a corner as SVG draws it",
        arguments: [
            (StrokeJoin.miter, [true, true, true]),
            (StrokeJoin.round, [false, true, true]),
            (StrokeJoin.bevel, [false, false, true])
        ]
    )
    func shapesJoin(
        join: StrokeJoin,
        inked: [Bool]
    ) throws {
        // Given
        let points = [Point(x: 10, y: 50), Point(x: 50, y: 50), Point(x: 50, y: 90)]
        let path = stroked(.polyline(points, isClosed: false), width: 20, join: join)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(58, 41), (56, 43), (52, 47)], inked: inked)
    }

    @Test("a miter longer than 4 times the stroke's width is drawn as a bevel")
    func bevelsMiterPastLimit() throws {
        // Given
        // The corner at (90, 50) turns by all but about 14 degrees, so its miter would be about 8 widths long.
        let points = [Point(x: 10, y: 40), Point(x: 90, y: 50), Point(x: 10, y: 60)]
        let path = stroked(.polyline(points, isClosed: false), width: 10, join: .miter)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        #expect(alpha(bitmap, 85, 50) > 0.99)
        #expect(alpha(bitmap, 93, 50) < 0.01)
    }

    // A 10 wide stroke ending at (70, 50): a round cap reaches 5 past the end as a half circle, a square cap as a half
    // square.
    @Test(
        "each cap shapes the ends of an open outline as SVG draws it",
        arguments: [
            (StrokeCap.butt, [true, false, false]),
            (StrokeCap.round, [true, true, false]),
            (StrokeCap.square, [true, true, true])
        ]
    )
    func shapesCap(
        cap: StrokeCap,
        inked: [Bool]
    ) throws {
        // Given
        let points = [Point(x: 30, y: 50), Point(x: 70, y: 50)]
        let path = stroked(.polyline(points, isClosed: false), width: 10, cap: cap)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(68, 50), (73, 50), (74, 45)], inked: inked)
    }

    // The outline of (10, 10, 80, 40) is 240 long from its top left corner: the top edge's middle at 40, the right
    // edge's middle at 100, the bottom edge's middle at 160 and the left edge's middle at 220.
    @Test(
        "a rect's stroke is drawn from its top left corner clockwise between the smaller and the larger trim",
        arguments: [
            (Trim(start: 0, end: 0.25), [true, false, false, false]),
            (Trim(start: 0.25, end: 0.5), [false, true, false, false]),
            (Trim(start: 0.75, end: 0.5), [false, false, true, false]),
            (Trim(start: 0, end: 1), [true, true, true, true]),
            (Trim(start: 0.5, end: 0.5), [false, false, false, false])
        ]
    )
    func trimsRect(
        trim: Trim,
        inked: [Bool]
    ) throws {
        // Given
        let path = stroked(.rect(Rectangle(x: 10, y: 10, width: 80, height: 40), radius: 0), width: 4, trim: trim)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(40, 10), (89, 30), (50, 49), (10, 30)], inked: inked)
    }

    // With corners of radius 10 the outline is 160 + 20π, about 222.8, long. Its first tenth runs along the top edge
    // from (20, 10) and its last tenth up the left edge from y = 26.6 and round the top left corner.
    @Test(
        "a rounded rect's outline starts where its top edge leaves the top left corner's arc",
        arguments: [
            (Trim(start: 0, end: 0.1), [true, false]),
            (Trim(start: 0.9, end: 1), [false, true])
        ]
    )
    func startsRoundedRectAfterArc(
        trim: Trim,
        inked: [Bool]
    ) throws {
        // Given
        let path = stroked(.rect(Rectangle(x: 10, y: 10, width: 80, height: 40), radius: 10), width: 4, trim: trim)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(30, 10), (10, 25)], inked: inked)
    }

    // The ellipse in (10, 30, 80, 40) has its top at (50, 30) and its right end at (90, 50). Its quarters are equally
    // long, and their middles lie near (78, 35), (78, 64), (21, 64) and (21, 35).
    @Test(
        "an ellipse's stroke is drawn from its top clockwise, a quarter of its length ending at its right end",
        arguments: [
            (Trim(start: 0, end: 0.25), [true, false, false, false, true, false]),
            (Trim(start: 0.75, end: 1), [false, false, false, true, false, false])
        ]
    )
    func trimsEllipse(
        trim: Trim,
        inked: [Bool]
    ) throws {
        // Given
        let path = stroked(.ellipse(Rectangle(x: 10, y: 30, width: 80, height: 40)), width: 4, trim: trim)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(78, 35), (78, 64), (21, 64), (21, 35), (89, 48), (89, 51)], inked: inked)
    }

    // The path runs 40 right from (10, 50) then 40 down from (50, 50), 80 long.
    @Test(
        "an open path's stroke is drawn from its first point along its points between the trims",
        arguments: [
            (Trim(start: 0, end: 0.5), [true, true, false, false]),
            (Trim(start: 0.25, end: 0.75), [false, true, true, false]),
            (Trim(start: 1, end: 0.5), [false, false, true, true])
        ]
    )
    func trimsOpenPath(
        trim: Trim,
        inked: [Bool]
    ) throws {
        // Given
        let points = [Point(x: 10, y: 50), Point(x: 50, y: 50), Point(x: 50, y: 90)]
        let path = stroked(.polyline(points, isClosed: false), width: 4, trim: trim)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(15, 50), (35, 50), (50, 65), (50, 85)], inked: inked)
    }

    @Test("an arrowhead is 4 times the stroke's width long and wide, its tip at the end, the line stopping at its base")
    func drawsArrowhead() throws {
        // Given
        // A 4 wide line to (90, 50): its head runs from its base at x = 74, 16 wide, to its tip.
        let points = [Point(x: 10, y: 50), Point(x: 90, y: 50)]
        let path = stroked(.polyline(points, isClosed: false), width: 4, end: .arrow)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(40, 51), (40, 53), (73, 43), (75, 43), (75, 41), (85, 49), (90, 50), (9, 50)], inked: [
            true, false, false, true, false, true, false, false
        ])
    }

    @Test("heads longer together than the drawn stroke shrink about their tips so their lengths add up to it")
    func shrinksArrowheads() throws {
        // Given
        // The stroke is 20 long and its two heads would be 16 each, so each is 10 long and 10 wide, their bases meeting
        // at x = 20.
        let points = [Point(x: 10, y: 50), Point(x: 30, y: 50)]
        let path = stroked(.polyline(points, isClosed: false), width: 4, start: .arrow, end: .arrow)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(19, 46), (20, 46), (24, 44), (14, 50), (8, 50), (31, 50)], inked: [
            true, true, false, true, false, false
        ])
    }

    @Test("an arrowhead sits at the end of the trimmed stroke, and a whole closed outline has none")
    func placesArrowheadOnTrimmedEnd() throws {
        // Given
        // Half of the 80 long line is drawn, to x = 50, its head from x = 34.
        let line = stroked(
            .polyline([Point(x: 10, y: 20), Point(x: 90, y: 20)], isClosed: false),
            width: 4,
            end: .arrow,
            trim: Trim(start: 0, end: 0.5)
        )
        let rect = stroked(.rect(Rectangle(x: 20, y: 50, width: 60, height: 40), radius: 0), width: 4, end: .arrow)

        // When
        let bitmap = try sut.frame(of: list([line, rect]))

        // Then
        // A head at the rect's end, its tip at (20, 50) pointing up the left edge, would cover (16, 62).
        expect(bitmap, at: [(35, 13), (60, 20), (16, 62)], inked: [true, false, false])
    }

    @Test("a translucent stroke and its heads are one shape, so where the line, its caps and heads overlap the alpha is not doubled")
    func drawsTranslucentStrokeOnce() throws {
        // Given
        let color = Color(written: "#00000080")
        let arrow = PathItem(
            geometry: .polyline([Point(x: 10, y: 20), Point(x: 90, y: 20)], isClosed: false),
            fill: nil,
            stroke: PathStroke(width: 4, color: color, join: .round, cap: .round, start: .none, end: .arrow)
        )
        let crossing = PathItem(
            geometry: .polyline(
                [Point(x: 10, y: 40), Point(x: 90, y: 90), Point(x: 90, y: 40), Point(x: 10, y: 90)],
                isClosed: false
            ),
            fill: nil,
            stroke: PathStroke(width: 6, color: color, join: .round, cap: .butt, start: .none, end: .none)
        )

        // When
        let bitmap = try sut.frame(of: list([arrow, crossing]))

        // Then
        // The round cap at the head's base, x = 74, reaches 2 into the head, and the path crosses itself at (50, 65).
        let half = 128.0 / 255
        for (x, y) in [(40, 20), (74, 20), (80, 20), (50, 65), (30, 52)] {
            #expect(abs(alpha(bitmap, x, y) - half) < 1.0 / 255, "pixel (\(x), \(y))")
        }
    }

    @Test("the fill is drawn first and whole, and the stroke over it, whatever the trim")
    func fillsUnderStroke() throws {
        // Given
        let path = PathItem(
            geometry: .rect(Rectangle(x: 20, y: 20, width: 60, height: 60), radius: 0),
            fill: Color(written: "#FF0000"),
            stroke: PathStroke(
                width: 8,
                color: Color(written: "#0000FF"),
                join: .miter,
                cap: .butt,
                start: .none,
                end: .none
            ),
            trim: Trim(start: 0, end: 0.25)
        )

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        #expect(bitmap.pixel(x: 50, y: 21) == [0, 0, 1, 1])
        #expect(bitmap.pixel(x: 50, y: 78) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 50, y: 50) == [1, 0, 0, 1])
    }

    // MARK: - Private
    private func list(_ paths: [PathItem]) -> DisplayList {
        DisplayList(
            size: Size(width: 100, height: 100),
            background: Color(written: "#00000000"),
            seed: 0,
            items: paths.map { DisplayItem(content: .path($0)) }
        )
    }

    private func stroked(
        _ geometry: PathGeometry,
        width: Double,
        join: StrokeJoin = .miter,
        cap: StrokeCap = .butt,
        start: StrokeEnd = .none,
        end: StrokeEnd = .none,
        trim: Trim = .whole
    ) -> PathItem {
        PathItem(
            geometry: geometry,
            fill: nil,
            stroke: PathStroke(width: width, color: Self.black, join: join, cap: cap, start: start, end: end),
            trim: trim
        )
    }

    private func alpha(
        _ bitmap: Bitmap,
        _ x: Int,
        _ y: Int
    ) -> Double {
        bitmap.pixel(x: x, y: y)[3]
    }

    private func expect(
        _ bitmap: Bitmap,
        at pixels: [(Int, Int)],
        inked: [Bool],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for ((x, y), isInked) in zip(pixels, inked) {
            let alpha = alpha(bitmap, x, y)
            #expect(
                isInked ? alpha > 0.99 : alpha < 0.01,
                "pixel (\(x), \(y)) has alpha \(alpha), expected \(isInked ? "inked" : "blank")",
                sourceLocation: sourceLocation
            )
        }
    }
}
