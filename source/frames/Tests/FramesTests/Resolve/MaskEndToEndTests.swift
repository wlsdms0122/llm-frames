//
//  MaskEndToEndTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// Each document is resolved, written, read back and evaluated, so a mask's leaves are followed from the document to
// the masks of the item drawn.
@Suite("Mask End To End Tests")
struct MaskEndToEndTests {
    // MARK: - Property
    private let writer = ResolvedDocumentWriter()
    private let reader = ResolvedDocumentReader()
    private let evaluator = Evaluator()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a mask moved only in its keyframes is drawn between them, its feather timed apart and its static keys kept")
    func drawsMaskMovedInKeyframes() throws {
        // Given
        let sut = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] }, "storyline": [ { "solid": "#202020", "duration": 4 } ],
              "clips": [ { "adjust": "frames/warm", "at": [0, 4], "mask": [ { "shape": "rect", "invert": true }, { "shape": "path", "mode": "subtract" } ],
                "keyframes": [
                  { "at": 1, "mask": [ { "area": [0, 0, 100, 100], "radius": 4 }, { "points": [[0, 0], [100, 0], [50, 100]] } ] },
                  { "at": 2, "mask": [ { "feather": 2 }, { } ] },
                  { "at": 3, "mask": [ { "area": [100, 0, 100, 100], "radius": 8 }, { "points": [[0, 100], [100, 100], [50, 200]] } ] } ] } ] }
            """#)

        // When
        let before = try masks(of: sut, at: 0)
        let between = try masks(of: sut, at: 2)
        let after = try masks(of: sut, at: 3.5)

        // Then
        #expect(before.map(\.geometry) == [
            .rect(Rectangle(x: 0, y: 0, width: 100, height: 100), radius: 4),
            .polyline([Point(x: 0, y: 0), Point(x: 100, y: 0), Point(x: 50, y: 100)], isClosed: true)
        ])
        #expect(between.map(\.geometry) == [
            .rect(Rectangle(x: 50, y: 0, width: 100, height: 100), radius: 6),
            .polyline([Point(x: 0, y: 50), Point(x: 100, y: 50), Point(x: 50, y: 150)], isClosed: true)
        ])
        #expect(after.map(\.geometry) == [
            .rect(Rectangle(x: 100, y: 0, width: 100, height: 100), radius: 8),
            .polyline([Point(x: 0, y: 100), Point(x: 100, y: 100), Point(x: 50, y: 200)], isClosed: true)
        ])
        // Only the keyframe at 2 writes the first mask's feather, so it holds 2 throughout; the second mask has none.
        #expect(before.map(\.feather) == [2, 0])
        #expect(between.map(\.isInverted) == [true, false])
        #expect(between.map(\.mode) == [.add, .subtract])
    }

    @Test("a path mask of two vertices with tangents is drawn as the lens its curves enclose, its box the curves'")
    func drawsCurvedMask() throws {
        // Given
        // Each segment's control points lie 40 above or below its ends at y = 50, so its middle lies 30 past them.
        let sut = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] }, "storyline": [ { "solid": "#202020", "duration": 4 } ],
              "clips": [ { "adjust": "frames/warm", "at": [0, 4], "mask": { "shape": "path", "points": [
                { "vertex": [0, 50], "inTangent": [0, 40], "outTangent": [0, -40] },
                { "vertex": [100, 50], "inTangent": [0, -40], "outTangent": [0, 40] } ] } } ] }
            """#)

        // When
        let mask = try #require(try masks(of: sut, at: 1).first)

        // Then
        #expect(mask.geometry == .path(
            [
                PathVertex(vertex: Point(x: 0, y: 50), inTangent: Point(x: 0, y: 40), outTangent: Point(x: 0, y: -40)),
                PathVertex(vertex: Point(x: 100, y: 50), inTangent: Point(x: 0, y: -40), outTangent: Point(x: 0, y: 40))
            ],
            isClosed: true
        ))
        #expect(mask.geometry.bounds(carriedBy: mask.transform) == Rectangle(x: 0, y: 20, width: 100, height: 60))
    }

    @Test("a box mask whose width alone is keyframed eases its width by its own keyframes, its height and centre held")
    func easesBoxWidthAlone() throws {
        // Given
        let sut = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] }, "storyline": [ { "solid": "#202020", "duration": 4 } ],
              "clips": [ { "adjust": "frames/warm", "at": [0, 4], "mask": { "shape": "ellipse", "height": 40, "position": [500, 300] },
                "keyframes": [ { "at": 0, "ease": "ease-in", "mask": { "width": 100 } }, { "at": 2, "mask": { "width": 300 } } ] } ] }
            """#)

        // When
        let middle = try masks(of: sut, at: 1)
        let written = try #require(try JSONReader().read(writer.write(sut)).objectValue?["clips"]?.arrayValue?.first?.objectValue)

        // Then
        let width = [Keyframe(at: 0, value: 100.0, ease: .easeIn), Keyframe(at: 2, value: 300.0)].value(at: 1)
        #expect(width < 200)
        #expect(middle.map(\.geometry) == [.ellipse(Rectangle(center: Point(x: 500, y: 300), width: width, height: 40))])
        #expect(written["mask"] == (try Fixture.json(#"""
            [ { "geometry": { "ellipse": {
                  "width": [ { "at": 0, "value": 100, "ease": "ease-in" }, { "at": 2, "value": 300, "ease": "linear" } ],
                  "height": [ { "at": 0, "value": 40, "ease": "linear" } ],
                  "position": [ { "at": 0, "value": [500, 300], "ease": "linear" } ] } },
                "feather": [ { "at": 0, "value": 0, "ease": "linear" } ], "invert": false, "mode": "add" } ]
            """#)))
    }

    @Test("a mask keyframe under a scaled parent shape is in the parent's space, drawn at the parent's scale")
    func drawsMaskUnderParent() throws {
        // Given
        let sut = try resolved(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "box", "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 600, 600], "scale": 2, "at": [0, 4] },
                { "adjust": "frames/warm", "parent": "box", "at": [0, 4], "mask": { "shape": "rect" }, "keyframes": [
                    { "at": 0, "mask": { "area": [0, 0, 100, 100] } },
                    { "at": 2, "mask": { "area": [0, 0, 50, 50] } } ] } ] } ] }
            """#)

        // When
        let first = try #require(try masks(of: sut, at: 0).first)
        let last = try #require(try masks(of: sut, at: 2).first)

        // Then
        // Each keyframe is in the box's space, drawn at twice its size.
        #expect(first.geometry == .rect(Rectangle(x: 0, y: 0, width: 100, height: 100), radius: 0))
        #expect(abs(drawn(first).width - 200) < 1e-6 && abs(drawn(first).height - 200) < 1e-6)
        #expect(last.geometry == .rect(Rectangle(x: 0, y: 0, width: 50, height: 50), radius: 0))
        #expect(abs(drawn(last).width - 100) < 1e-6 && abs(drawn(last).height - 100) < 1e-6)
    }

    @Test(
        "a stop on a mask written alone names it without an index, and one in a list with its index",
        arguments: [
            (
                #""mask": { "shape": "rect" }, "keyframes": [ { "at": 0, "mask": { "area": [0, 0, 10, 10] } }, { "at": 1, "mask": { "width": 10 } } ]"#,
                "clips[0].keyframes[1].mask.width (keyframe): the clip and its keyframes write different forms: area, width"
            ),
            (
                #""mask": [ { "shape": "rect" } ], "keyframes": [ { "at": 0, "mask": { "area": [0, 0, 10, 10] } }, { "at": 1, "mask": [ { "width": 10 } ] } ]"#,
                "clips[0].keyframes[1].mask[0].width (keyframe): the clip and its keyframes write different forms: area, width"
            ),
            (
                #""mask": { "shape": "rect", "area": [0, 0, 10, 10] }, "keyframes": [ { "at": 0, "mask": [ { "area": [0, 0, 20, 20] } ] } ]"#,
                "clips[0].mask.area: written as a static value and in every keyframe that writes it, so the static value never shows"
            ),
            (
                #""keyframes": [ { "at": 0, "mask": { "area": [0, 0, 10, 10] } } ]"#,
                #"clips[0].mask (adjustment): missing key "shape", which the clip does not write and no theme layer gives"#
            )
        ]
    )
    func namesLoneMaskStop(
        keys: String,
        message: String
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1920, 1080] }, "storyline": [ { "solid": "#202020", "duration": 2 } ],
              "clips": [ { "adjust": "frames/warm", "at": [0, 2], \#(keys) } ] }
            """#

        // When, Then
        let error = #expect(throws: (any Error).self) { try resolved(document) }
        #expect((error as? CustomStringConvertible)?.description == message)
    }

    // MARK: - Private
    // The document resolved, written and read back, which must give the same sequence.
    private func resolved(_ document: String) throws -> ResolvedSequence {
        let sequence = try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
        let read = try reader.read(writer.write(sequence))
        #expect(read == sequence)

        return read
    }

    // The masks of the adjustment item drawn at `time`.
    private func masks(
        of sequence: ResolvedSequence,
        at time: Double
    ) throws -> [ItemMask] {
        let list = evaluator.displayList(of: sequence, at: time)
        let item = try #require(list.items.last { $0.origin?.kind == "adjustment" })

        return item.mask
    }

    // A rect mask's rectangle in output pixels.
    private func drawn(_ mask: ItemMask) -> Rectangle {
        guard case let .rect(rectangle, _) = mask.geometry else { return Rectangle(x: 0, y: 0, width: 0, height: 0) }

        return Rectangle(bounding: mask.transform.apply(toCornersOf: rectangle))
    }
}
