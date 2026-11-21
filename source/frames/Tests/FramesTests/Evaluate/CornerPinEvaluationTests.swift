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

    @Test("a storyline clip with a corner pin draws its group inside the inner list at opacity 1, its opacity and blend on the outer item")
    func drawsStorylineGroup() throws {
        // Given
        let sequence = try resolved(document: #"{ "kind": "sequence", "storyline": [ { "id": "shot", "media": "/abs/run.mp4", "cornerPin": \#(Self.pin), "opacity": 0.5, "blend": "screen" } ] }"#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let size = try #require(sequence.storyline.first?.cornerPin?.size)
        let box = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        let outer = try #require(list.items.first)
        guard case let .picture(storyline) = outer.content, case let .displayList(inner) = storyline.source else {
            Issue.record("the storyline item is not a picture of a nested list")
            return
        }
        #expect(outer.opacity == 0.5)
        #expect(outer.blend == "screen")
        #expect(inner.items.count == 1)
        let group = try #require(inner.items.first)
        guard case let .picture(picture) = group.content, case let .displayList(nested) = picture.source else {
            Issue.record("the inner item is not a picture of a nested list")
            return
        }
        #expect(group.transform == .identity)
        #expect(group.opacity == 1)
        #expect(group.blend == "normal")
        #expect(picture.cornerPin == Self.quad)
        #expect(picture.rectangle == box)
        #expect(picture.destination == box)
        #expect(nested.size == size)
        #expect(nested.items.first?.transform == .identity)
        guard case let .picture(media) = nested.items.first?.content else {
            Issue.record("the nested item is not a picture")
            return
        }
        #expect(media.destination == box)
        #expect(media.cornerPin == nil)
    }

    @Test("a storyline clip with a corner pin and a shadow carries its masks inside the group, moved with its box")
    func carriesStorylineMasksInGroup() throws {
        // Given
        let sequence = try resolved(document: ##"""
            { "kind": "sequence", "storyline": [ { "id": "shot", "media": "/abs/run.mp4", "cornerPin": \##(Self.pin),
              "shadow": { "radius": 10, "offset": [0, 0], "color": "#000000" },
              "mask": [ { "shape": "rect", "area": [0, 0, 100, 100] } ] } ] }
            """##)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let entry = try #require(sequence.storyline.first)
        guard
            case let .picture(storyline) = list.items.first?.content,
            case let .displayList(inner) = storyline.source,
            let group = inner.items.first,
            case let .picture(picture) = group.content,
            case let .displayList(nested) = picture.source,
            let item = nested.items.first
        else {
            Issue.record("the storyline item does not hold a group")
            return
        }
        // The shadow's radius of 10 is 5.625 output pixels and reaches three times that past the box.
        let shift = AffineTransform(translation: Point(x: 16.875, y: 16.875))
        #expect(picture.rectangle?.x == 16.875)
        #expect(picture.rectangle?.y == 16.875)
        #expect(group.mask.isEmpty)
        #expect(item.transform == shift)
        #expect(item.mask.map(\.transform) == entry.masks(at: SampleTime(1)).map { $0.transform.concatenating(shift) })
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

    @Test("a title animated by unit with a corner pin draws its units' group as the one item of its own group's list")
    func drawsUnitGroupInGroup() throws {
        // Given
        let sequence = try resolved(#"{ "id": "card", "title": "ab cd", "style": "title", "at": [0, 4], "cornerPin": \#(Self.pin), "animation": { "preset": "frames/fade", "by": "word" } }"#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        guard
            case let .picture(picture) = list.items.last?.content,
            case let .displayList(nested) = picture.source,
            case let .picture(units) = nested.items.first?.content,
            case let .displayList(unitList) = units.source
        else {
            Issue.record("the group's list does not hold the title's units as a picture of a nested list")
            return
        }
        #expect(picture.cornerPin == Self.quad)
        #expect(nested.items.count == 1)
        #expect(unitList.size == nested.size)
        #expect(unitList.items.count > 1)
    }

    @Test("a clip with a corner pin cuts its item by its masks inside the group, in its box, and the group by none")
    func cutsMasksInsideGroup() throws {
        // Given
        let sequence = try resolved(#"{ "id": "card", "media": "/abs/page.png", "width": 300, "at": [0, 4], "cornerPin": \#(Self.pin), "mask": [ { "shape": "rect", "area": [0, 0, 500, 400] } ] }"#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let group = try #require(list.items.last)
        guard case let .picture(picture) = group.content, case let .displayList(nested) = picture.source else {
            Issue.record("the group is not a picture of a nested list")
            return
        }
        // The mask is in the media's pixels, 1000 by 800, which the box of 300 by 240 shows.
        let mask = try #require(nested.items.first?.mask.first)
        let corner = mask.transform.apply(to: Point(x: 500, y: 400))
        #expect(group.mask.isEmpty)
        #expect(nested.items.first?.mask.count == 1)
        #expect(abs(corner.x - 150) < 1e-9 && abs(corner.y - 120) < 1e-9)
    }

    @Test("a tracked corner pin brings back each keyframe of numbers at its own time, though another keyframe holds a clip area, so it draws at that time what it writes")
    func bringsBackNumberKeyframeBesideClipArea() throws {
        // Given
        // From media second 0.1 the target [0, 0, 100, 100] is seen as a trapezoid, so the track's homography there is
        // not its motion. The untracked clip draws the same four points as the tracked one's keyframe at 0.5.
        let target = Quad(Rectangle(x: 0, y: 0, width: 100, height: 100))
        let far = Quad(topLeft: Point(x: 0, y: 0), topRight: Point(x: 100, y: 0), bottomRight: Point(x: 60, y: 50), bottomLeft: Point(x: 40, y: 50))
        let quads = [(0.0, target)] + (1...10).map { (Double($0) / 10, far) }
        let corners = ["top-left", "top-right", "bottom-right", "bottom-left"]
            .map { #"{ "area": { "clip": "bar" }, "point": "\#($0)" }"# }
            .joined(separator: ", ")
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "out": 1, "connected": [
                { "id": "bar", "shape": "rect", "fill": "accent", "area": [20, 20, 60, 30], "parent": "screen", "at": [0, 1] },
                { "id": "tracked", "media": "/abs/card.png", "parent": "screen", "at": [0, 1], "width": 300, "track": { "time": 0, "area": [0, 0, 100, 100] },
                  "keyframes": [ { "at": 0.5, "cornerPin": [[10, 10], [90, 10], [90, 40], [10, 40]] },
                                 { "at": 0.9, "cornerPin": [\#(corners)] } ] },
                { "id": "still", "media": "/abs/card.png", "parent": "screen", "at": [0, 1], "width": 300,
                  "cornerPin": [[10, 10], [90, 10], [90, 40], [10, 40]] } ] } ] }
            """#
        let sequence = try resolved(document: document, tracker: QuadTrackerTable(base: target, quads: quads))

        // When
        let list = sut.displayList(of: sequence, at: 0.5)

        // Then
        let drawn = { (id: String) throws -> [Point] in
            let item = try #require(list.items.first { $0.origin?.id == id })
            guard case let .picture(picture) = item.content else {
                Issue.record("the group is not a picture")
                return []
            }

            return try #require(picture.cornerPin).corners.map(item.transform.apply)
        }
        let tracked = try drawn("tracked")
        let still = try drawn("still")
        #expect(tracked.count == 4)
        #expect(zip(tracked, still).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 })
    }

    // MARK: - Private
    private func resolved(
        document: String,
        tracker: any TrackerProvider
    ) throws -> ResolvedSequence {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: Fixture.presets,
            ocr: Fixture.ocr,
            languages: nil,
            tracker: tracker,
            shaper: Fixture.shaper,
            library: Fixture.library
        )

        return try ResolvedSequence(plan: planner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    private func resolved(_ clips: String) throws -> ResolvedSequence {
        try resolved(document: #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ \#(clips) ] }"#)
    }

    private func resolved(document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }
}
