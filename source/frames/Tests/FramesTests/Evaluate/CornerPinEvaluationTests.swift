//
//  CornerPinEvaluationTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

// `/abs/page.png` is 1000 by 800 pixels, so a media clip of it with a `width` of 300 has the box [0, 0, 300, 240]. The
// frame is 1080 pixels wide, so a written length of 10 is 5.625 output pixels.
@Suite("CornerPinEvaluation Tests")
struct CornerPinEvaluationTests {
    // MARK: - Property
    private static let pin = "[[100, 100], [500, 120], [480, 400], [120, 380]]"
    private static let quad = Quad(
        topLeft: Point(x: 100, y: 100),
        topRight: Point(x: 500, y: 120),
        bottomRight: Point(x: 480, y: 400),
        bottomLeft: Point(x: 120, y: 380)
    )

    private let sut = Evaluator()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a media clip with a corner pin is one group: a picture of a nested list of its box, carried onto its corner pin")
    func drawsGroup() throws {
        // Given
        let sequence = try resolved(#"{ "id": "card", "media": "/abs/page.png", "width": 300, "at": [0, 4], "cornerPin": \#(Self.pin), "opacity": 0.5, "blend": "screen" }"#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let group = try #require(list.items.last)
        guard case let .picture(picture) = group.content, case let .displayList(nested) = picture.source else {
            Issue.record("the group is not a picture of a nested list")
            return
        }
        #expect(group.transform == .identity)
        #expect(group.opacity == 0.5)
        #expect(group.blend == "screen")
        #expect(picture.cornerPin == Self.quad)
        #expect(picture.rectangle == Rectangle(x: 0, y: 0, width: 300, height: 240))
        #expect(picture.destination == Rectangle(x: 0, y: 0, width: 300, height: 240))
        #expect(nested.size == Size(width: 300, height: 240))
        #expect(nested.items.count == 1)
        #expect(nested.items.first?.transform == .identity)
        #expect(nested.items.first?.opacity == 1)
        #expect(nested.items.first?.blend == "normal")
        guard case let .picture(inner) = nested.items.first?.content else {
            Issue.record("the nested item is not a picture")
            return
        }
        #expect(inner.destination == Rectangle(x: 0, y: 0, width: 300, height: 240))
        #expect(inner.cornerPin == nil)
    }

    @Test("a rect given by width and height with a corner pin is one group whose nested list draws its path in its box")
    func drawsBoxShapeGroup() throws {
        // Given
        let sequence = try resolved(##"{ "id": "card", "shape": "rect", "width": 300, "height": 240, "fill": "#FFFFFF", "at": [0, 4], "cornerPin": \##(Self.pin) }"##)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let size = try #require(sequence.clips.first?.cornerPin?.size)
        let box = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        let group = try #require(list.items.last)
        guard
            case let .picture(picture) = group.content,
            case let .displayList(nested) = picture.source,
            case let .path(path) = nested.items.first?.content,
            case let .rect(rectangle, _) = path.geometry
        else {
            Issue.record("the group is not a picture of a nested list holding the rect's path")
            return
        }
        #expect(group.transform == .identity)
        #expect(picture.cornerPin == Self.quad)
        #expect(picture.destination == box)
        #expect(nested.size == size)
        #expect(nested.items.first?.transform == .identity)
        #expect(rectangle == box)
    }

    @Test("a shadow past the box grows the nested list, with the box's top left at minus the list's origin")
    func growsListByShadow() throws {
        // Given
        let sequence = try resolved(##"{ "id": "card", "media": "/abs/page.png", "width": 300, "at": [0, 4], "cornerPin": \##(Self.pin), "shadow": { "radius": 10, "offset": [0, 0], "color": "#000000" } }"##)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        guard case let .picture(picture) = list.items.last?.content, case let .displayList(nested) = picture.source else {
            Issue.record("the group is not a picture of a nested list")
            return
        }
        #expect(picture.rectangle == Rectangle(x: 16.875, y: 16.875, width: 300, height: 240))
        #expect(picture.destination == Rectangle(x: 0, y: 0, width: 300, height: 240))
        #expect(nested.size == Size(width: 333.75, height: 273.75))
        #expect(nested.items.first?.transform == AffineTransform(translation: Point(x: 16.875, y: 16.875)))
    }

    @Test("a corner pin keyframed to its mirror draws nothing where its interpolated corners are not strictly convex")
    func drawsNothingWhereFolded() throws {
        // Given
        let sequence = try resolved(#"""
            { "id": "card", "media": "/abs/page.png", "width": 300, "at": [0, 4], "keyframes": [
              { "at": 0, "cornerPin": [[100, 100], [500, 100], [500, 400], [100, 400]] },
              { "at": 2, "cornerPin": [[500, 100], [100, 100], [100, 400], [500, 400]] } ] }
            """#)

        // When
        let folded = sut.displayList(of: sequence, at: 1)
        let mirrored = sut.displayList(of: sequence, at: 2)

        // Then
        #expect(!folded.items.contains { $0.origin?.id == "card" })
        #expect(mirrored.items.contains { $0.origin?.id == "card" })
    }

    @Test("a sibling's clip area naming a clip with a corner pin takes its corner pin bounds, its padding not divided by a length factor")
    func takesCornerPinBounds() throws {
        // Given
        let sequence = try resolved(#"""
            { "id": "card", "media": "/abs/page.png", "width": 300, "at": [0, 4], "cornerPin": \#(Self.pin) },
            { "id": "frame", "shape": "rect", "area": { "clip": "card", "padding": 10 }, "fill": "#FFFFFF", "at": [0, 4] }
            """#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        guard case let .path(path) = list.items.last?.content, case let .rect(rect, _) = path.geometry else {
            Issue.record("the sibling is not a rect")
            return
        }
        #expect(rect == Rectangle(x: 94.375, y: 94.375, width: 411.25, height: 311.25))
    }

    @Test("a child of a clip with a corner pin is placed in the space the corner pin is written in, not on its plane")
    func placesChildInWrittenSpace() throws {
        // Given
        let sequence = try resolved(#"""
            { "id": "card", "media": "/abs/page.png", "width": 300, "at": [0, 4], "cornerPin": \#(Self.pin) },
            { "id": "dot", "shape": "rect", "area": [10, 20, 30, 40], "fill": "#FFFFFF", "parent": "card", "at": [0, 4] }
            """#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let child = try #require(list.items.last)
        #expect(child.origin?.id == "dot")
        #expect(child.transform == .identity)
    }

    // MARK: - Private
    private func resolved(_ clips: String) throws -> ResolvedSequence {
        let document = #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ \#(clips) ] }"#
        return try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }
}
