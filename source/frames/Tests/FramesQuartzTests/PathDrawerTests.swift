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
    // From (10, 20) to (90, 20), both tangents (0, 80): the curve bulges to y = 80 at x = 50, its middle, where it
    // heads along x. Its points are (10 + 240 (1 - t) t² + 80 t³, 20 + 240 t (1 - t)).
    private static let bulge = PathGeometry.path(
        [
            PathVertex(vertex: Point(x: 10, y: 20), inTangent: Point(x: 0, y: 0), outTangent: Point(x: 0, y: 80)),
            PathVertex(vertex: Point(x: 90, y: 20), inTangent: Point(x: 0, y: 80), outTangent: Point(x: 0, y: 0))
        ],
        isClosed: false
    )
    // A 4 wide line from (10, 50) to its end at (90, 50), so u is 4 at scale 1 and 8 at scale 2, and every head is 4u
    // wide across the line, its sides at y = 50 - 2u and 50 + 2u. An arrow and a line arrow reach a pixel 2 back from
    // the tip on the line, a circle and a diamond 1 back, a square and a bar the last pixel. The other probes lie just
    // inside and just outside a head's side near its base, 4u back, or u for a bar, and behind its base. A line
    // arrow's bands at scale 2 are 8 thick, and between them the line runs to their inner corner √5 u back, with blank
    // on each side of it.
    private static let headsAtEnd: [(StrokeEndShape, Double, [(Int, Int)], [(Int, Int)])] = [
        (.arrow, 1, [(87, 49), (87, 50), (20, 49), (75, 43)], [(75, 41), (72, 43)]),
        (.arrow, 2, [(87, 49), (87, 50), (20, 49), (59, 35)], [(59, 33), (56, 35)]),
        (.lineArrow, 1, [(87, 49), (87, 50), (20, 49), (75, 43), (75, 55)], [(75, 41), (72, 43)]),
        (.lineArrow, 2, [(87, 49), (87, 50), (20, 49), (59, 35), (59, 60), (62, 50)], [(59, 33), (56, 35), (59, 53), (59, 46)]),
        (.circle, 1, [(88, 49), (88, 50), (20, 49), (82, 43)], [(82, 41), (74, 42), (72, 43)]),
        (.circle, 2, [(88, 49), (88, 50), (20, 49), (74, 35)], [(74, 33), (58, 34), (56, 35)]),
        (.square, 1, [(89, 49), (89, 50), (20, 49), (74, 42)], [(74, 41), (73, 42)]),
        (.square, 2, [(89, 49), (89, 50), (20, 49), (58, 34)], [(58, 33), (57, 34)]),
        (.diamond, 1, [(88, 49), (88, 50), (20, 49), (82, 43)], [(82, 41), (74, 42)]),
        (.diamond, 2, [(88, 49), (88, 50), (20, 49), (74, 35)], [(74, 33), (58, 34)]),
        (.bar, 1, [(89, 49), (89, 50), (20, 49), (86, 42)], [(86, 41), (85, 42)]),
        (.bar, 2, [(89, 49), (89, 50), (20, 49), (82, 34)], [(82, 33), (81, 34)])
    ]

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
        let path = PathItem(geometry: .polyline(points, isClosed: true), fill: .color(Self.black), stroke: nil)

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
        let path = PathItem(geometry: .polyline(points, isClosed: false), fill: .color(Self.black), stroke: nil)

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

    @Test("a curved segment is stroked along its curve, and a trim to its first half stops at its middle")
    func strokesCurve() throws {
        // Given
        let geometry = Self.bulge

        // When
        let whole = try sut.frame(of: list([stroked(geometry, width: 4)]))
        let half = try sut.frame(of: list([stroked(geometry, width: 4, trim: Trim(start: 0, end: 0.5))]))

        // Then
        expect(whole, at: [(50, 80), (50, 20), (50, 50)], inked: [true, false, false])
        expect(half, at: [(46, 79), (54, 79), (10, 22), (90, 22)], inked: [true, false, true, false])
    }

    // From (25, 25) to (75, 25) with control points (75, 75) and (25, 75): the curve runs down into a cusp at
    // (50, 62.5) and turns back up. A 10 wide stroke reaches 62.5 there, and a round join rounds it to 67.5; the turn
    // is half a circle, past the miter limit, so a miter is bevelled flat at the cusp as a bevel is.
    @Test(
        "a cusp inside one curved segment takes the stroke's join",
        arguments: [
            (StrokeJoin.miter, [true, false, false]),
            (StrokeJoin.round, [true, true, true]),
            (StrokeJoin.bevel, [true, false, false])
        ]
    )
    func joinsAtCusp(
        join: StrokeJoin,
        inked: [Bool]
    ) throws {
        // Given
        let geometry = PathGeometry.path(
            [
                PathVertex(vertex: Point(x: 25, y: 25), inTangent: Point(x: 0, y: 0), outTangent: Point(x: 50, y: 50)),
                PathVertex(vertex: Point(x: 75, y: 25), inTangent: Point(x: -50, y: 50), outTangent: Point(x: 0, y: 0))
            ],
            isClosed: false
        )

        // When
        let bitmap = try sut.frame(of: list([stroked(geometry, width: 10, join: join)]))

        // Then
        expect(bitmap, at: [(49, 58), (49, 65), (50, 65)], inked: inked)
    }

    // The curve of `strokesCurve` trimmed to its first half ends at its middle (50, 80), heading along x. A 10 wide
    // round cap reaches 5 past it as a half circle, a square cap as a half square to x = 55, y = 75 and y = 85.
    @Test(
        "a trim end inside a curve takes the stroke's cap along the curve's direction there",
        arguments: [
            (StrokeCap.butt, [true, false, false]),
            (StrokeCap.round, [true, true, false]),
            (StrokeCap.square, [true, true, true])
        ]
    )
    func capsTrimEndInsideCurve(
        cap: StrokeCap,
        inked: [Bool]
    ) throws {
        // Given
        let path = stroked(Self.bulge, width: 10, cap: cap, trim: Trim(start: 0, end: 0.5))

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(47, 79), (52, 79), (54, 75)], inked: inked)
    }

    // Dashes and gaps of an eighth of the curve's arc length each, measured independently by a polyline of 20000
    // chords. A pixel holding the point 3 back from where an eighth ends lies in that eighth and one holding the point
    // 3 on in the next, so each dash's ends are drawn within 1.5 of where the arc length puts them.
    @Test("dashes along a curve are laid by its arc length")
    func laysDashesByArcLength() throws {
        // Given
        let samples = (0...20_000).map { index in
            let t = Double(index) / 20_000
            return Point(x: 10 + 240 * (1 - t) * t * t + 80 * t * t * t, y: 20 + 240 * t * (1 - t))
        }
        var lengths = [0.0]
        for (point, next) in zip(samples, samples.dropFirst()) {
            lengths.append(lengths[lengths.count - 1] + hypot(next.x - point.x, next.y - point.y))
        }
        let eighth = lengths[lengths.count - 1] / 8
        let pixel = { (distance: Double) -> (Int, Int) in
            let index = lengths.firstIndex { $0 >= distance } ?? lengths.count - 1
            return (Int(samples[index].x), Int(samples[index].y))
        }
        let stroke = PathStroke(
            width: 8,
            paint: .color(Self.black),
            join: .miter,
            cap: .butt,
            start: .none,
            end: .none,
            dash: [eighth, eighth]
        )

        // When
        let bitmap = try sut.frame(of: list([PathItem(geometry: Self.bulge, fill: nil, stroke: stroke)]))

        // Then
        let ends = (1..<8).map { Double($0) * eighth }
        expect(bitmap, at: ends.map { pixel($0 - 3) }, inked: (0..<7).map { $0.isMultiple(of: 2) })
        expect(bitmap, at: ends.map { pixel($0 + 3) }, inked: (1..<8).map { $0.isMultiple(of: 2) })
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

    @Test(
        "each head lies with its tip at the end of the outline, nothing of it past the end, 4u wide across and as long as its shape at u = width × scale",
        arguments: headsAtEnd
    )
    func drawsHeadAtEnd(
        shape: StrokeEndShape,
        scale: Double,
        inked: [(Int, Int)],
        blank: [(Int, Int)]
    ) throws {
        // Given
        let points = [Point(x: 10, y: 50), Point(x: 90, y: 50)]
        let path = stroked(.polyline(points, isClosed: false), width: 4, end: StrokeEnd(shape: shape, scale: scale))

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: inked + blank, inked: inked.map { _ in true } + blank.map { _ in false })
        let past = (0..<100).flatMap { y in (90..<100).map { x in (x, y) } }.filter { x, y in alpha(bitmap, x, y) >= 0.01 }
        #expect(past.isEmpty, "\(past.count) pixels at or past the end are drawn, first \(past.prefix(4))")
    }

    // At scale 2 on the bulge, whose last stretch turns from heading up and right to heading straight up at (90, 20),
    // the arrow is 32 long and its base lies 32 back along the curve at (84.8, 51.4), so its axis tilts 9.3 degrees from
    // the tangent at the tip and its base corners lie at (69.1, 48.8) and (100.6, 54.0). (76, 42) lies inside it and
    // outside a head laid along the tangent, and (99, 42) the other way round.
    @Test("a head on a curved end lies along the chord from its base on the curve to its tip, nothing of it past the end")
    func drawsHeadOnCurvedEnd() throws {
        // Given
        let path = stroked(Self.bulge, width: 4, end: StrokeEnd(shape: .arrow, scale: 2))

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(89, 22), (89, 23), (76, 42), (84, 50), (99, 42)], inked: [true, true, true, true, false])
        let past = (0..<20).flatMap { y in (0..<100).map { x in (x, y) } }.filter { x, y in alpha(bitmap, x, y) >= 0.01 }
        #expect(past.isEmpty, "\(past.count) pixels above the tip are drawn, first \(past.prefix(4))")
    }

    // The stroke is 20 long. A circle at scale 1 and a bar at scale 2 would be 16 and 8 long, so both shrink by 20 / 24:
    // the circle to 13.3 across from its tip at x = 10, its centre at 16.7, and the bar to 6.7 long and 26.7 across,
    // from x = 23.3 to its front at 30, the circle's base. The circle's top is at y = 43.3, and the bar unshrunk would
    // cover (24, 35).
    @Test("heads longer together than the drawn stroke shrink by one factor, each keeping its shape, so their lengths add up to it")
    func shrinksHeadsByOneFactor() throws {
        // Given
        let points = [Point(x: 10, y: 50), Point(x: 30, y: 50)]
        let path = stroked(
            .polyline(points, isClosed: false),
            width: 4,
            start: StrokeEnd(shape: .circle),
            end: StrokeEnd(shape: .bar, scale: 2)
        )

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(16, 44), (11, 49), (24, 37), (29, 40), (16, 42), (9, 49), (24, 35), (30, 40)], inked: [
            true, true, true, true, false, false, false, false
        ])
    }

    // A circle at scale 1 starts the stroke, centred at x = 18 with a radius of 8, and a line arrow at scale 2 ends it,
    // from its base at x = 58, its inner corner, where the line stops, at 72.1. Dashes of 6 every 16 from x = 10 fall
    // at 26, 42, 58 and 74: the one at 58 runs inside the line arrow's open middle, and the gap after it shows there.
    @Test("heads on a dashed stroke are drawn whole, and the dashes run to where each head stops the line")
    func drawsHeadsOverDashes() throws {
        // Given
        let stroke = PathStroke(
            width: 4,
            paint: .color(Self.black),
            join: .miter,
            cap: .butt,
            start: StrokeEnd(shape: .circle),
            end: StrokeEnd(shape: .lineArrow, scale: 2),
            dash: [6, 10]
        )
        let path = PathItem(geometry: .polyline([Point(x: 10, y: 50), Point(x: 90, y: 50)], isClosed: false), fill: nil, stroke: stroke)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(18, 43), (28, 49), (36, 49), (44, 49), (52, 49), (60, 49), (68, 49), (59, 60), (87, 49)], inked: [
            true, true, false, true, false, true, false, true, true
        ])
    }

    @Test("a translucent stroke and its heads are one shape, so where the line, its caps and heads overlap the alpha is not doubled")
    func drawsTranslucentStrokeOnce() throws {
        // Given
        let color = Color(written: "#00000080")
        let arrow = PathItem(
            geometry: .polyline([Point(x: 10, y: 20), Point(x: 90, y: 20)], isClosed: false),
            fill: nil,
            stroke: PathStroke(width: 4, paint: .color(color), join: .round, cap: .round, start: .none, end: .arrow)
        )
        let crossing = PathItem(
            geometry: .polyline(
                [Point(x: 10, y: 40), Point(x: 90, y: 90), Point(x: 90, y: 40), Point(x: 10, y: 90)],
                isClosed: false
            ),
            fill: nil,
            stroke: PathStroke(width: 6, paint: .color(color), join: .round, cap: .butt, start: .none, end: .none)
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
            fill: .color(Color(written: "#FF0000")),
            stroke: PathStroke(
                width: 8,
                paint: .color(Color(written: "#0000FF")),
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

    // A rect at (20, 40) 60 by 40 is 200 long round, so a trim to 61 / 200 ends 1 below its top right corner, at the
    // head's tip, and its base lies 16 back along the stroke on the top edge, so the head runs along the chord between
    // them and its upper base corner lies 8 above the rect. An ellipse 60 by 30 trimmed to 0.15 ends where its curve
    // has turned, so the chord from its base to its tip lies inside it and the head's outer base corner past its top.
    // Both heads reach past the stroked outline.
    @Test(
        "a trimmed rect ending just past a corner and a trimmed ellipse draw their whole arrowhead inside the box of what they draw",
        arguments: [
            (true, Rectangle(x: 20, y: 40, width: 60, height: 40), Trim(start: 0, end: 61.0 / 200), 4.0),
            (false, Rectangle(x: 20, y: 35, width: 60, height: 30), Trim(start: 0, end: 0.15), 5.0)
        ]
    )
    func keepsArrowheadInDrawnBounds(
        isRect: Bool,
        outline: Rectangle,
        trim: Trim,
        width: Double
    ) throws {
        // Given
        let geometry: PathGeometry = isRect ? .rect(outline, radius: 0) : .ellipse(outline)
        let path = stroked(geometry, width: width, end: .arrow, trim: trim)

        // When
        let whole = try sut.frame(of: list([path]))

        // Then
        let above = Int(outline.y - width / 2)
        let pixels = (0..<100).flatMap { y in (0..<100).map { x in (x, y) } }
        #expect(pixels.contains { x, y in y < above && alpha(whole, x, y) > 0.99 }, "the head is drawn above \(above)")
        try expectDrawnInsideBounds(of: path)
    }

    // A polyline turning back by 36.87 degrees at (80, 50) has a miter 3.16 stroke widths long, under the limit of 4,
    // so its point reaches 15.8 past the corner, where the outline grown by half the width reaches 5. A square cap on
    // a diagonal end reaches its corner half the width along and half across it, 7.07 out along each axis. Each probe
    // lies wholly past the outline grown by half the width and wholly inside the join or the cap.
    @Test(
        "a sharp miter join and a square cap on a diagonal end are drawn whole inside the box of what the path draws",
        arguments: [
            (
                PathGeometry.polyline([Point(x: 20, y: 30), Point(x: 80, y: 50), Point(x: 20, y: 70)], isClosed: false),
                StrokeJoin.miter,
                StrokeCap.butt,
                87,
                49
            ),
            (
                PathGeometry.polyline([Point(x: 30, y: 30), Point(x: 70, y: 70)], isClosed: false),
                StrokeJoin.round,
                StrokeCap.square,
                75,
                70
            )
        ]
    )
    func keepsJoinAndCapInDrawnBounds(
        geometry: PathGeometry,
        join: StrokeJoin,
        cap: StrokeCap,
        x: Int,
        y: Int
    ) throws {
        // Given
        let path = stroked(geometry, width: 10, join: join, cap: cap)

        // When
        let whole = try sut.frame(of: list([path]))

        // Then
        #expect(alpha(whole, x, y) > 0.99, "pixel (\(x), \(y)) past the grown outline is drawn")
        try expectDrawnInsideBounds(of: path)
    }

    @Test("a stroke under a transform that scales its axes apart is as wide on every side in output pixels")
    func drawsNonScalingStroke() throws {
        // Given
        // A 20 by 40 rect at [2, 1]: the output outline runs from (20, 20) to (60, 60), its stroke 4 wide about it, so
        // the top side covers the pixel rows 18 to 21 and the left side the columns 18 to 21.
        let path = stroked(.rect(Rectangle(x: 10, y: 20, width: 20, height: 40), radius: 0), width: 4)
        let item = DisplayItem(transform: AffineTransform(a: 2, b: 0, c: 0, d: 1, tx: 0, ty: 0), content: .path(path))
        let list = DisplayList(size: Size(width: 100, height: 100), background: Color(written: "#00000000"), seed: 0, items: [item])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(
            bitmap,
            at: [(40, 17), (40, 18), (40, 21), (40, 22), (17, 40), (18, 40), (21, 40), (22, 40), (40, 40)],
            inked: [false, true, true, false, false, true, true, false, false]
        )
    }

    @Test("the arrowhead under a transform that scales its axes apart keeps its shape, 4 times the width long")
    func drawsNonScalingArrowhead() throws {
        // Given
        // A 4 wide line to (45, 50) at [2, 1] ends at (90, 50) on the output, its head from x = 74, 16 wide.
        let points = [Point(x: 5, y: 50), Point(x: 45, y: 50)]
        let path = stroked(.polyline(points, isClosed: false), width: 4, end: .arrow)
        let item = DisplayItem(transform: AffineTransform(a: 2, b: 0, c: 0, d: 1, tx: 0, ty: 0), content: .path(path))
        let list = DisplayList(size: Size(width: 100, height: 100), background: Color(written: "#00000000"), seed: 0, items: [item])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(bitmap, at: [(40, 51), (40, 53), (73, 43), (75, 43), (75, 41), (85, 49), (90, 50)], inked: [
            true, false, false, true, false, true, false
        ])
    }

    @Test(
        "dashes are laid from the start of the stroke as drawn, moved back by the offset, and carried with the outline",
        arguments: [
            // Dashes of 10 from x = 10: 10 to 20, 30 to 40.
            (Trim.whole, 0.0, Frames.AffineTransform.identity, [15, 35], [25, 45]),
            // Moved back by 5: 10 to 15, 25 to 35.
            (Trim.whole, 5.0, Frames.AffineTransform.identity, [12, 28], [18, 38]),
            // Trimmed from x = 30, the pattern starts there: 30 to 40, 50 to 60.
            (Trim(start: 0.25, end: 1), 0.0, Frames.AffineTransform.identity, [35, 55], [15, 45]),
            // Drawn on to x = 35, the dashes stay where the whole stroke has them: 10 to 20, 30 to 35.
            (Trim(start: 0, end: 0.3125), 0.0, Frames.AffineTransform.identity, [15, 32], [25, 38]),
            // The line drawn at half its length, scaled 2 along x: each dash stays 10 long on the output.
            (Trim.whole, 0.0, Frames.AffineTransform(a: 2, b: 0, c: 0, d: 1, tx: -10, ty: 0), [15, 35], [25, 45])
        ]
    )
    func drawsDashes(
        trim: Trim,
        offset: Double,
        transform: Frames.AffineTransform,
        inked: [Int],
        blank: [Int]
    ) throws {
        // Given
        let isScaled = transform.a != 1
        let end = isScaled ? Point(x: 50, y: 50) : Point(x: 90, y: 50)
        let stroke = PathStroke(
            width: 4,
            paint: .color(Self.black),
            join: .miter,
            cap: .butt,
            start: .none,
            end: .none,
            dash: isScaled ? [5, 5] : [10, 10],
            dashOffset: isScaled ? offset / 2 : offset
        )
        let path = PathItem(
            geometry: .polyline([Point(x: 10, y: 50), end], isClosed: false),
            fill: nil,
            stroke: stroke,
            trim: trim
        )
        let item = DisplayItem(transform: transform, content: .path(path))
        let list = DisplayList(size: Size(width: 100, height: 100), background: Color(written: "#00000000"), seed: 0, items: [item])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        expect(bitmap, at: (inked + blank).map { ($0, 50) }, inked: inked.map { _ in true } + blank.map { _ in false })
    }

    @Test("an arrowhead on a dashed stroke is drawn whole, and the dashes stop at its base")
    func drawsArrowheadOverDashes() throws {
        // Given
        // The head runs from x = 74 to its tip at 90; the dashes of 2 every 32 fall at 10, 42 and 74.
        let stroke = PathStroke(width: 4, paint: .color(Self.black), join: .miter, cap: .butt, start: .none, end: .arrow, dash: [2, 30])
        let path = PathItem(geometry: .polyline([Point(x: 10, y: 50), Point(x: 90, y: 50)], isClosed: false), fill: nil, stroke: stroke)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(10, 50), (30, 50), (42, 50), (60, 50), (78, 50), (85, 50), (80, 53)], inked: [
            true, false, true, false, true, true, true
        ])
    }

    // Dots of no length every 20 from x = 10, 10 wide: a round one is a circle of radius 5, a square one a square
    // reaching 5 each way, whose corner pixel (34, 54) lies past the circle.
    @Test(
        "a dash of no length draws its caps alone, a dot for round and a square for square, and nothing for butt",
        arguments: [
            (StrokeCap.butt, [false, false, false]),
            (StrokeCap.round, [true, false, false]),
            (StrokeCap.square, [true, true, false])
        ]
    )
    func drawsZeroLengthDash(
        cap: StrokeCap,
        inked: [Bool]
    ) throws {
        // Given
        let stroke = PathStroke(width: 10, paint: .color(Self.black), join: .miter, cap: cap, start: .none, end: .none, dash: [0, 20])
        let path = PathItem(geometry: .polyline([Point(x: 10, y: 50), Point(x: 90, y: 50)], isClosed: false), fill: nil, stroke: stroke)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(30, 50), (34, 54), (40, 50)], inked: inked)
    }

    @Test("a dash whose lengths are all 0, as a sample of a frame with motion blur writes one, draws the stroke whole")
    func drawsAllZeroDashWhole() throws {
        // Given
        let stroke = { (dash: [Double]?) in
            PathStroke(width: 4, paint: .color(Self.black), join: .miter, cap: .round, start: .none, end: .arrow, dash: dash)
        }
        let path = { (dash: [Double]?) in
            PathItem(
                geometry: .polyline([Point(x: 10, y: 50), Point(x: 90, y: 50)], isClosed: false),
                fill: nil,
                stroke: stroke(dash),
                trim: Trim(start: 0, end: 0.8)
            )
        }

        // When
        let bitmap = try sut.frame(of: list([path([0, 0])]))

        // Then
        #expect(bitmap == (try sut.frame(of: list([path(nil)]))))
        expect(bitmap, at: [(20, 50), (40, 50)], inked: [true, true])
    }

    // A circle of radius 20 about (50, 50), stretched 2 along x about its centre into an ellipse 40 by 20. Dashes of a
    // quarter of the circle's length from its top, clockwise, fall on the top right and bottom left quarters.
    @Test("dashes on an ellipse stretched along x follow the outline as carried, longer along the stretched axis")
    func carriesDashesOnStretchedEllipse() throws {
        // Given
        let quarter = Double.pi * 10
        let stroke = PathStroke(width: 4, paint: .color(Self.black), join: .miter, cap: .butt, start: .none, end: .none, dash: [quarter, quarter])
        let path = PathItem(geometry: .ellipse(Rectangle(x: 30, y: 30, width: 40, height: 40)), fill: nil, stroke: stroke)
        let item = DisplayItem(transform: Frames.AffineTransform(a: 2, b: 0, c: 0, d: 1, tx: -50, ty: 0), content: .path(path))
        let list = DisplayList(size: Size(width: 100, height: 100), background: Color(written: "#00000000"), seed: 0, items: [item])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        // The points of the ellipse halfway along each quarter.
        expect(bitmap, at: [(78, 35), (78, 64), (21, 64), (21, 35)], inked: [true, false, true, false])
    }

    // A 10 wide stroke on an outline whose left side lies along x = 20 and whose middle row is y = 50: inside it covers
    // x from 20 to 30, centred from 15 to 25 and outside from 10 to 20. The circle of radius 30 about (50, 50) reaches
    // x = 20 on that row, and its stroke is the same band there within a hundredth of a pixel. The closed path is the
    // rect's square wound the other way, which leaves its inside where it is.
    @Test(
        "a stroke's width lies inside, centred on or outside its outline as its align says, on a rect, an ellipse and a closed path",
        arguments: [
            PathGeometry.rect(Rectangle(x: 20, y: 20, width: 60, height: 60), radius: 0),
            .ellipse(Rectangle(x: 20, y: 20, width: 60, height: 60)),
            .polyline([Point(x: 20, y: 20), Point(x: 20, y: 80), Point(x: 80, y: 80), Point(x: 80, y: 20)], isClosed: true)
        ],
        [
            (StrokeAlign.inside, [false, false, false, true, true, false]),
            (StrokeAlign.center, [false, false, true, true, false, false]),
            (StrokeAlign.outside, [false, true, true, false, false, false])
        ]
    )
    func alignsStroke(
        geometry: PathGeometry,
        expectation: (StrokeAlign, [Bool])
    ) throws {
        // Given
        let (align, inked) = expectation
        let path = stroked(geometry, width: 10, align: align)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(8, 49), (12, 49), (17, 49), (22, 49), (28, 49), (32, 49)], inked: inked)
        try expectDrawnInsideBounds(of: path)
    }

    // A 10 wide stroke outside the square from (20, 20) to (80, 80): the miter fills the corner square from (10, 10) to
    // (20, 20), and the round join the quarter circle of radius 10 about (20, 20), which leaves (11, 11) out.
    @Test(
        "an outside stroke's miter join keeps a square corner square and its round join rounds it by the stroke's width",
        arguments: [(StrokeJoin.miter, [true, true]), (StrokeJoin.round, [false, true])]
    )
    func joinsOutsideStroke(
        join: StrokeJoin,
        inked: [Bool]
    ) throws {
        // Given
        let square = PathGeometry.rect(Rectangle(x: 20, y: 20, width: 60, height: 60), radius: 0)
        let path = stroked(square, width: 10, align: .outside, join: join)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(11, 11), (15, 15)], inked: inked)
    }

    // The top left corner of the rect from (20, 20) to (80, 80) is an arc of radius 10 about (30, 30). A 10 wide stroke
    // covers the distances from (30, 30) up to 10 inside, from 5 to 15 centred and from 10 to 20 outside: pixel (25, 25)
    // lies from 5.7 to 7.1, pixel (17, 17) from 17 to 18.4 and pixel (12, 12) past 24.
    @Test(
        "a stroke on a rounded rect follows its rounded corners on the side its align names",
        arguments: [
            (StrokeAlign.inside, [true, false, false]),
            (StrokeAlign.center, [true, false, false]),
            (StrokeAlign.outside, [false, true, false])
        ]
    )
    func alignsStrokeOnRoundedRect(
        align: StrokeAlign,
        inked: [Bool]
    ) throws {
        // Given
        let path = stroked(.rect(Rectangle(x: 20, y: 20, width: 60, height: 60), radius: 10), width: 10, align: align)

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, at: [(25, 25), (17, 17), (12, 12)], inked: inked)
        expect(bitmap, at: [(12, 49), (28, 49)], inked: [align == .outside, align == .inside])
        try expectDrawnInsideBounds(of: path)
    }

    // The top edge of the rect from (20, 20) to (80, 80) is trimmed to x from 30 to 70, its first sixth of 240 being
    // the 10 from (20, 20) along it and its last the 50 from there, so (24, 25) lies before the piece.
    @Test("a trimmed and dashed inside stroke is the wider stroke's piece and dashes cut to the inside of the outline")
    func cutsTrimmedDashedInsideStroke() throws {
        // Given
        let path = PathItem(
            geometry: .rect(Rectangle(x: 20, y: 20, width: 60, height: 60), radius: 0),
            fill: nil,
            stroke: PathStroke(
                width: 10,
                paint: .color(Self.black),
                align: .inside,
                join: .miter,
                cap: .butt,
                start: .none,
                end: .none,
                dash: [10, 10]
            ),
            trim: Trim(start: 10.0 / 240, end: 50.0 / 240)
        )

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        // The dashes lie from x = 30 to 40 and from 50 to 60 along the top edge, 10 deep below it.
        expect(
            bitmap,
            at: [(34, 25), (54, 25), (44, 25), (24, 25), (34, 17), (64, 25)],
            inked: [true, true, false, false, false, false]
        )
        try expectDrawnInsideBounds(of: path)
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
        align: StrokeAlign = .center,
        join: StrokeJoin = .miter,
        cap: StrokeCap = .butt,
        start: StrokeEnd = .none,
        end: StrokeEnd = .none,
        trim: Trim = .whole
    ) -> PathItem {
        PathItem(
            geometry: geometry,
            fill: nil,
            stroke: PathStroke(
                width: width,
                paint: .color(Self.black),
                align: align,
                join: join,
                cap: cap,
                start: start,
                end: end
            ),
            trim: trim
        )
    }

    // Every pixel wholly outside the box of what the path draws is blank, and every pixel wholly inside it is drawn
    // the same with the box as its reveal as without. A pixel the box's edge crosses is left out: the clip's smoothed
    // edge scales its part of the pixel.
    private func expectDrawnInsideBounds(
        of path: PathItem,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let box = path.drawnBounds(carriedBy: .identity)
        let revealed = DisplayList(
            size: Size(width: 100, height: 100),
            background: Color(written: "#00000000"),
            seed: 0,
            items: [DisplayItem(reveal: box, content: .path(path))]
        )
        let whole = try sut.frame(of: list([path]))
        let clipped = try sut.frame(of: revealed)
        let (maxX, maxY) = (box.x + box.width, box.y + box.height)
        let pixels = (0..<100).flatMap { y in (0..<100).map { x in (x, y) } }
        let inside = pixels.filter { x, y in
            Double(x) >= box.x && Double(x + 1) <= maxX && Double(y) >= box.y && Double(y + 1) <= maxY
        }
        let outside = pixels.filter { x, y in
            Double(x + 1) <= box.x || Double(x) >= maxX || Double(y + 1) <= box.y || Double(y) >= maxY
        }
        let drawnOutside = outside.filter { x, y in alpha(whole, x, y) > 1e-6 }
        #expect(
            drawnOutside.isEmpty,
            "\(drawnOutside.count) pixels are drawn outside the box, first \(drawnOutside.prefix(4))",
            sourceLocation: sourceLocation
        )
        let cut = inside.filter { x, y in abs(alpha(whole, x, y) - alpha(clipped, x, y)) > 1e-6 }
        #expect(
            cut.isEmpty,
            "the box cuts \(cut.count) pixels inside it, first \(cut.prefix(4))",
            sourceLocation: sourceLocation
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
