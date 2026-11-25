//
//  ShippedHeadPresetTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames
@testable import FramesCommand

// The head presets frames ships, read from the tool's own resource bundle as the tool reads them, with no pack
// installed beside them, each laid on the end of a straight stroke from (0, 0) to (100, 0).
@Suite("ShippedHeadPreset Tests")
struct ShippedHeadPresetTests {
    // MARK: - Property
    private static let names = ["arrow", "line-arrow", "circle", "square", "diamond", "bar"]

    // The outlines, lengths and insets FRAMES-16 gives each head, in units.
    private static let heads: [String: StrokeHead] = {
        let reach = (4 - 5.0.squareRoot()) / 2
        let tangent = 4.0 / 3 * (2.0.squareRoot() - 1) * 2
        let straight = { (points: [(Double, Double)]) in
            points.map { PathVertex(vertex: Point(x: $0.0, y: $0.1), inTangent: Point(x: 0, y: 0), outTangent: Point(x: 0, y: 0)) }
        }
        let circle = [
            PathVertex(vertex: Point(x: 0, y: 0), inTangent: Point(x: 0, y: -tangent), outTangent: Point(x: 0, y: tangent)),
            PathVertex(vertex: Point(x: -2, y: 2), inTangent: Point(x: tangent, y: 0), outTangent: Point(x: -tangent, y: 0)),
            PathVertex(vertex: Point(x: -4, y: 0), inTangent: Point(x: 0, y: tangent), outTangent: Point(x: 0, y: -tangent)),
            PathVertex(vertex: Point(x: -2, y: -2), inTangent: Point(x: -tangent, y: 0), outTangent: Point(x: tangent, y: 0))
        ]

        return [
            "arrow": StrokeHead(outline: straight([(-4, 2), (0, 0), (-4, -2)]), length: 4, inset: 4),
            "line-arrow": StrokeHead(
                outline: straight([(0, 0), (-4, 2), (-4, reach), (-(5.0.squareRoot()), 0), (-4, -reach), (-4, -2)]),
                length: 4,
                inset: 5.0.squareRoot()
            ),
            "circle": StrokeHead(outline: circle, length: 4, inset: 2),
            "square": StrokeHead(outline: straight([(0, 2), (0, -2), (-4, -2), (-4, 2)]), length: 4, inset: 2),
            "diamond": StrokeHead(outline: straight([(0, 0), (-2, -2), (-4, 0), (-2, 2)]), length: 4, inset: 2),
            "bar": StrokeHead(outline: straight([(0, 2), (0, -2), (-1, -2), (-1, 2)]), length: 1, inset: 0.5)
        ]
    }()

    private let directory: TemporaryDirectory
    private let shipped = CommandEnvironment.current.shippedPacks
    private let sut: PresetLibrary
    private let outline = PathOutline(.polyline([Point(x: 0, y: 0), Point(x: 100, y: 0)], isClosed: false))

    // MARK: - Initializer
    init() throws {
        directory = try TemporaryDirectory()
        sut = PresetLibrary(
            packs: PackLibrary(
                installed: URL(fileURLWithPath: directory.file("installed"), isDirectory: true),
                shipped: shipped
            )
        )
    }

    // MARK: - Test
    @Test("the shipped heads are exactly the six that FRAMES-16 names")
    func namesShippedHeads() throws {
        // Given, When
        let names = try sut.presets(of: .head).map(\.name)

        // Then
        #expect(names.sorted() == Self.names.map { "frames/\($0)" }.sorted())
    }

    @Test("every shipped head reads and says in one capitalised sentence how it looks", arguments: names)
    func readsHead(name: String) throws {
        // Given, When
        let entry = try #require(try sut.presets(of: .head).first { $0.name == "frames/\(name)" })

        // Then
        #expect(entry.parameters.isEmpty)
        #expect(!entry.description.contains("\n"))
        #expect(entry.description.first?.isUppercase == true)
        #expect(entry.description.hasSuffix("."))
        #expect(!entry.description.dropLast().contains(". "))
    }

    @Test(
        "every shipped head on a straight end is its FRAMES-16 outline at u to a unit, its tip at the end, its base its length back and the line stopping at its inset",
        arguments: names,
        [1.0, 2.5]
    )
    func laysHeadOnStraightEnd(
        name: String,
        scale: Double
    ) throws {
        // Given
        let head = try #require(try sut.head(named: "frames/\(name)"))
        let expected = try #require(Self.heads[name])
        let drawn = drawn(end: StrokeEnd(head: head, scale: scale))
        let unit = 4 * scale

        // When
        let laid = try #require(outline.arrowheads(of: drawn).first)

        // Then
        guard case let .path(vertices, isClosed) = laid.geometry() else {
            Issue.record("a head's geometry is a path")
            return
        }
        let points = expected.outline.map { vertex in
            (
                vertex: Point(x: 100 + vertex.vertex.x * unit, y: vertex.vertex.y * unit),
                inTangent: Point(x: vertex.inTangent.x * unit, y: vertex.inTangent.y * unit),
                outTangent: Point(x: vertex.outTangent.x * unit, y: vertex.outTangent.y * unit)
            )
        }
        #expect(isClosed)
        #expect(laid.tip == Point(x: 100, y: 0))
        #expect(vertices.count == points.count)
        for (vertex, point) in zip(vertices, points) {
            #expect(isClose(vertex.vertex, point.vertex))
            #expect(isClose(vertex.inTangent, point.inTangent))
            #expect(isClose(vertex.outTangent, point.outTangent))
        }
        #expect(isClose(laid.transform.apply(to: Point(x: -expected.length, y: 0)), Point(x: 100 - expected.length * unit, y: 0)))
        #expect(abs(outline.lineEnd(of: drawn) - (100 - expected.inset * unit)) < 1e-9)
    }

    // Four cubic segments lie up to 0.027% of the radius off a true circle (FRAMES-16), 0.004 px for this radius of
    // 16, so the drawn curve is checked against the circle to 0.01 px.
    @Test("the shipped circle on a straight end draws a circle 4u across within 0.01 px, its front at the end and its centre 2u back")
    func drawsCircleOnStraightEnd() throws {
        // Given
        let head = try #require(try sut.head(named: "frames/circle"))
        let drawn = drawn(end: StrokeEnd(head: head, scale: 2))
        let center = Point(x: 84, y: 0)

        // When
        let laid = try #require(outline.arrowheads(of: drawn).first)

        // Then
        guard case let .path(vertices, _) = laid.geometry() else {
            Issue.record("a head's geometry is a path")
            return
        }
        for (index, vertex) in vertices.enumerated() {
            let next = vertices[(index + 1) % vertices.count]
            for step in 0...32 {
                let point = cubic(
                    vertex.vertex,
                    Point(x: vertex.vertex.x + vertex.outTangent.x, y: vertex.vertex.y + vertex.outTangent.y),
                    Point(x: next.vertex.x + next.inTangent.x, y: next.vertex.y + next.inTangent.y),
                    next.vertex,
                    at: Double(step) / 32
                )
                #expect(abs(hypot(point.x - center.x, point.y - center.y) - 16) < 0.01)
                #expect(point.x <= 100 + 1e-9)
            }
        }
    }

    // MARK: - Private
    // A stroke 4 wide along the outline, ending in `end`.
    private func drawn(end: StrokeEnd) -> DrawnStroke {
        DrawnStroke(
            stroke: PathStroke(width: 4, paint: .color(Color(written: "#FF0000")), join: .miter, cap: .butt, start: .none, end: end),
            trim: .whole,
            isClosed: false
        )
    }

    private func isClose(
        _ point: Point,
        _ other: Point
    ) -> Bool {
        abs(point.x - other.x) < 1e-9 && abs(point.y - other.y) < 1e-9
    }

    private func cubic(
        _ start: Point,
        _ first: Point,
        _ second: Point,
        _ end: Point,
        at fraction: Double
    ) -> Point {
        let rest = 1 - fraction
        let weights = (
            rest * rest * rest,
            3 * rest * rest * fraction,
            3 * rest * fraction * fraction,
            fraction * fraction * fraction
        )

        return Point(
            x: weights.0 * start.x + weights.1 * first.x + weights.2 * second.x + weights.3 * end.x,
            y: weights.0 * start.y + weights.1 * first.y + weights.2 * second.y + weights.3 * end.y
        )
    }
}
