//
//  ParentSpacePlannerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

// In `/abs/screen.mp4` "Total" starts as `Fixture.total` and moves 10 right and 40 down per second while it grows by
// `growth` of its size per second, and the tracker follows a target the same way. The screen fills the output, so its
// media pixels are output pixels.
@Suite("ParentSpacePlanner Tests")
struct ParentSpacePlannerTests {
    // MARK: - Property
    private static let drift = Point(x: 10, y: 40)
    private static let padding = 14.0

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a title at a point of text beside a tracked box lands beside the text on every frame, though its instant is not the box's",
        arguments: [
            (0.0, "box"),
            (0.25, "box"),
            (0.25, "inner")
        ]
    )
    func placesTextBesideTrackedBox(
        growth: Double,
        parent: String
    ) throws {
        // Given
        let sut = planner(growth: growth)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "box", "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "at": [0, 4], "area": { "text": "Total" }, "track": true },
                { "id": "inner", "shape": "rect", "stroke": { "width": 8 }, "parent": "box", "at": [0, 4], "area": [0, 0, 10, 10] },
                { "title": "a", "style": "title", "parent": "\#(parent)", "at": [2, 4], "anchor": "left",
                  "position": { "area": { "text": "Total", "padding": 14 }, "point": "right" } } ] } ] }
            """#)

        // When
        let resolved = try ResolvedSequence(
            plan: sut.plan(Fixture.planner.plan(document: document)),
            hashes: FileHashTable()
        )

        // Then
        let title = try #require(resolved.clips.last)
        let box = try #require(title.box)
        let parents = ParentEvaluator(sequence: resolved)
        for time in [2.0, 2.5, 3.5] {
            let space = parents.space(of: title, at: time)
            let anchor = space.transform.apply(to: space.anchor(of: box, track: nil, at: time))
            // The padding is found at the title's instant and grows with the text from there.
            let text = Self.text(at: time, growth: growth)
            let padding = Self.padding * (1 + growth * time) / (1 + growth * 2)
            let beside = Point(x: text.x + text.width + padding, y: text.center.y)
            #expect(isClose(anchor, beside), "at \(time) the title is at \(anchor), the text's right at \(beside)")
        }
    }

    @Test(
        "a title whose instant or keyframe lies outside its tracked box's window lands where the same title under the screen does",
        arguments: [
            (
                #""at": [2, 4], "position": \#(Self.beside)"#,
                [2.0, 3.0, 3.5]
            ),
            (
                #""at": [0, 4], "keyframes": [ { "at": 1, "position": \#(Self.beside) }, { "at": 3, "position": \#(Self.beside) } ]"#,
                [1.0, 3.0, 3.5]
            )
        ]
    )
    func placesTextOutsideTrackedBoxWindow(
        title: String,
        times: [Double]
    ) throws {
        // Given
        let sut = planner(growth: 0.25)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "box", "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "at": [0, 2], "area": { "text": "Total" }, "track": true },
                { "title": "a", "style": "title", "parent": "box", "anchor": "left", \#(title) },
                { "title": "a", "style": "title", "parent": "screen", "anchor": "left", \#(title) } ] } ] }
            """#)

        // When
        let resolved = try ResolvedSequence(
            plan: sut.plan(Fixture.planner.plan(document: document)),
            hashes: FileHashTable()
        )

        // Then
        let underBox = resolved.clips[1]
        let underScreen = resolved.clips[2]
        let parents = ParentEvaluator(sequence: resolved)
        for time in times {
            let anchor = Self.anchor(of: underBox, by: parents, at: time)
            let expected = Self.anchor(of: underScreen, by: parents, at: time)
            #expect(isClose(anchor, expected), "at \(time) the title is at \(anchor), the screen's title at \(expected)")
        }
    }

    @Test("numbers under a tracked box are kept as written, and a text keyframe beside them is brought into its space")
    func keepsNumbersUnderTrackedBox() throws {
        // Given
        let sut = planner(growth: 0)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "box", "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "at": [0, 4], "area": { "text": "Total" }, "track": true },
                { "shape": "rect", "stroke": { "width": 8 }, "parent": "box", "at": [0, 4], "area": [300, 100, 50, 50] },
                { "title": "a", "style": "title", "parent": "box", "at": [0, 4], "anchor": "left", "keyframes": [
                    { "at": 2, "position": [300, 100] },
                    { "at": 3, "position": { "area": { "text": "Total", "padding": 14 }, "point": "right" } } ] } ] } ] }
            """#)

        // When
        let plan = try sut.plan(Fixture.planner.plan(document: document))

        // Then
        guard case let .value(area) = plan.clips[1].area else {
            Issue.record("the area was not found")
            return
        }
        #expect(area.rectangle == Rectangle(x: 300, y: 100, width: 50, height: 50))
        guard case let .keyframes(positions) = plan.clips[2].position else {
            Issue.record("the position was not keyframed")
            return
        }
        let total = Fixture.total
        let beside = Point(x: total.x + total.width + Self.padding, y: total.center.y)
        let numbers = try #require(positions.first)
        let text = try #require(positions.last)
        #expect(numbers.value == .point(Point(x: 300, y: 100)))
        #expect(isClose(text.value.fixed, beside), "the text keyframe is at \(text.value), the text's right at \(beside)")
    }

    @Test(
        "a title at a point of text under a turned and scaled shape lands beside the text, the shape held at its window's edge",
        arguments: [
            #""at": [0, 4], "scale": 1.5, "rotation": 30"#,
            #""at": [0, 4], "anchor": "top-left", "position": [400, 500], "scale": 0.5, "rotation": -90"#,
            #""at": [0, 4], "keyframes": [ { "at": 0, "scale": 1, "rotation": 0 }, { "at": 4, "scale": 2, "rotation": 90 } ]"#,
            #""at": [0, 1], "keyframes": [ { "at": 0, "position": [0, 0], "rotation": 0 }, { "at": 1, "position": [300, 200], "rotation": 60 } ]"#
        ]
    )
    func placesTextUnderTurnedShape(card: String) throws {
        // Given
        let sut = planner(growth: 0)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "card", "shape": "rect", "fill": "accent", "parent": "screen", "area": [200, 300, 400, 200], \#(card) },
                { "title": "a", "style": "title", "parent": "card", "at": [2, 4], "anchor": "left", "position": \#(Self.beside) } ] } ] }
            """#)

        // When
        let resolved = try ResolvedSequence(
            plan: sut.plan(Fixture.planner.plan(document: document)),
            hashes: FileHashTable()
        )

        // Then
        let anchor = Self.anchor(of: resolved.clips[1], by: ParentEvaluator(sequence: resolved), at: 2)
        let text = Self.text(at: 2, growth: 0)
        let beside = Point(x: text.x + text.width + Self.padding, y: text.center.y)
        #expect(isClose(anchor, beside), "the title is at \(anchor), the text's right at \(beside)")
    }

    @Test("a title at a point of text under a turned rect with an outset and a named anchor, in a space at half scale, lands beside the text")
    func placesTextUnderOutsetShapeInZoomedSpace() throws {
        // Given
        // The screen is drawn at half its size, so the card's outset of 20 output pixels is 40 of its media pixels
        // when it is drawn. Its anchor is the top left of its area as written, whatever the outset.
        let sut = planner(growth: 0)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "scale": 0.5, "connected": [
                { "id": "card", "shape": "rect", "fill": "accent", "parent": "screen", "area": [200, 300, 400, 200],
                  "outset": 20, "anchor": "top-left", "scale": 1.5, "rotation": 30, "at": [0, 4] },
                { "title": "a", "style": "title", "parent": "card", "at": [2, 4], "anchor": "left", "position": \#(Self.beside) } ] } ] }
            """#)

        // When
        let resolved = try ResolvedSequence(
            plan: sut.plan(Fixture.planner.plan(document: document)),
            hashes: FileHashTable()
        )

        // Then
        let parents = ParentEvaluator(sequence: resolved)
        let anchor = Self.anchor(of: resolved.clips[1], by: parents, at: 2)
        let text = Self.text(at: 2, growth: 0)
        let beside = parents.space(of: resolved.clips[0], at: 2).transform
            .apply(to: Point(x: text.x + text.width + Self.padding, y: text.center.y))
        #expect(isClose(anchor, beside), "the title is at \(anchor), the text's right at \(beside)")
    }

    @Test(
        "a title at a point of text under a tracked, scaled rect whose area keyframes are not at its instant and whose anchor is named lands beside the text at every time"
    )
    func placesTextUnderTrackedKeyframedArea() throws {
        // Given
        // The card names its target, so its instant is 0, and its area is keyed at 1 and 3, after it: where the area
        // lies at the instant is its keyframes brought back through the motion at their own times.
        let sut = planner(growth: 0)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "card", "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "at": [0, 4],
                  "track": { "text": "Total" }, "anchor": "top-left", "scale": 1.5, "rotation": 20,
                  "keyframes": [ { "at": 1, "area": { "text": "Total" } }, { "at": 3, "area": [300, 400, 200, 100] } ] },
                { "title": "a", "style": "title", "parent": "card", "at": [2, 4], "anchor": "left",
                  "position": { "area": { "text": "Total", "padding": 14 }, "point": "right" } } ] } ] }
            """#)

        // When
        let resolved = try ResolvedSequence(
            plan: sut.plan(Fixture.planner.plan(document: document)),
            hashes: FileHashTable()
        )

        // Then
        let parents = ParentEvaluator(sequence: resolved)
        for time in [2.0, 3.5] {
            let anchor = Self.anchor(of: resolved.clips[1], by: parents, at: time)
            let text = Self.text(at: time, growth: 0)
            let beside = Point(x: text.x + text.width + Self.padding, y: text.center.y)
            #expect(isClose(anchor, beside), "at \(time) the title is at \(anchor), the text's right at \(beside)")
        }
    }

    @Test("an area of text under a turned and scaled shape is the box bounding its four corners carried back, and numbers are kept")
    func bringsAreaBackThroughRotation() throws {
        // Given
        let sut = planner(growth: 0)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "card", "shape": "rect", "fill": "accent", "parent": "screen", "at": [0, 4], "area": [200, 300, 400, 200],
                  "scale": 1.5, "rotation": 30 },
                { "shape": "rect", "stroke": { "width": 8 }, "parent": "card", "at": [2, 4], "area": { "text": "Total" } },
                { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "at": [2, 4], "area": { "text": "Total" } },
                { "shape": "rect", "stroke": { "width": 8 }, "parent": "card", "at": [2, 4], "area": [300, 100, 50, 50] } ] } ] }
            """#)

        // When
        let plan = try sut.plan(Fixture.planner.plan(document: document))

        // Then
        guard case let .value(underCard) = plan.clips[1].area,
            case let .value(onScreen) = plan.clips[2].area,
            case let .value(numbers) = plan.clips[3].area
        else {
            Issue.record("the areas were not found as static values")
            return
        }
        let card = AffineTransform(scale: 1.5, rotation: 30, about: Point(x: 400, y: 400), offset: Point(x: 0, y: 0))
        let inverse = try #require(card.inverse)
        let expected = Rectangle(bounding: inverse.apply(toCornersOf: onScreen.rectangle))
        #expect(isClose(underCard.rectangle, expected), "the area is \(underCard.rectangle), the carried corners' box \(expected)")
        // Turned by 30 degrees, the wide line of text stands taller than its height at that scale.
        #expect(underCard.rectangle.height > onScreen.rectangle.height / 1.5)
        #expect(numbers.rectangle == Rectangle(x: 300, y: 100, width: 50, height: 50))
    }

    @Test("text found under a shape whose scale is 0 on an axis at the value's instant stops, naming the clip and the instant")
    func stopsUnderFlatParent() throws {
        // Given
        let sut = planner(growth: 0)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "card", "shape": "rect", "fill": "accent", "parent": "screen", "at": [0, 4], "area": [200, 300, 400, 200],
                  "scale": [2, 0] },
                { "shape": "rect", "stroke": { "width": 8 }, "parent": "card", "at": [2, 4], "area": { "text": "Total" } } ] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(Fixture.planner.plan(document: document)) }
        #expect(error?.description == "storyline[0]#screen.connected[1].area (rect): found by text at 2, where its parent's "
            + "transform has a scale of 0 on an axis and cannot be undone to bring it into the parent's space")
    }

    @Test("a path's point of text under a turned and scaled shape is carried back into its space, and a point of numbers is kept")
    func bringsPointsBackThroughRotation() throws {
        // Given
        let sut = planner(growth: 0)
        let points = #"[\#(Self.beside), [0, 0]]"#
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "card", "shape": "rect", "fill": "accent", "parent": "screen", "at": [0, 4], "area": [200, 300, 400, 200],
                  "scale": 1.5, "rotation": 30 },
                { "shape": "path", "stroke": { "width": 8 }, "parent": "card", "at": [2, 4], "points": \#(points) },
                { "shape": "path", "stroke": { "width": 8 }, "parent": "screen", "at": [2, 4], "points": \#(points) } ] } ] }
            """#)

        // When
        let plan = try sut.plan(Fixture.planner.plan(document: document))

        // Then
        guard case let .value(underCard) = plan.clips[1].points, case let .value(onScreen) = plan.clips[2].points else {
            Issue.record("the points were not found as static values")
            return
        }
        let card = AffineTransform(scale: 1.5, rotation: 30, about: Point(x: 400, y: 400), offset: Point(x: 0, y: 0))
        let expected = try #require(card.inverse).apply(to: onScreen[0].fixed)
        #expect(isClose(underCard[0].fixed, expected), "the point is \(underCard[0]), carried back \(expected)")
        #expect(underCard[1] == .point(Point(x: 0, y: 0)))
    }

    @Test("a chain of 64 shapes, each finding its area by text under the one before, resolves and evaluates in place")
    func bringsBackThroughDeepChain() throws {
        // Given
        // Each shape's text is brought back through every shape above it, which would be planned again for every
        // level below if a parent's transform were not kept, and every walk up the chain is as deep as the chain.
        let sut = planner(growth: 0)
        let count = 64
        let shapes = (0..<count).map { index in
            let parent = index == 0 ? "screen" : "s\(index - 1)"
            return #"""
                { "id": "s\#(index)", "shape": "rect", "stroke": { "width": 8 }, "parent": "\#(parent)", "at": [0, 4],
                  "area": { "text": "Total" } }
                """#
        }
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                \#(shapes.joined(separator: ", ")) ] } ] }
            """#)

        // When
        let plan = try sut.plan(Fixture.planner.plan(document: document))
        let list = Evaluator().displayList(of: try ResolvedSequence(plan: plan, hashes: FileHashTable()), at: 1)

        // Then
        guard case let .value(first) = plan.clips[0].area, case let .value(last) = plan.clips[count - 1].area else {
            Issue.record("the areas were not found as static values")
            return
        }
        // No shape above moves its space, so the text lies where the first shape found it, and each is drawn there.
        #expect(isClose(last.rectangle, first.rectangle), "the last area is \(last.rectangle), the first \(first.rectangle)")
        let drawn = list.items.compactMap { item -> Rectangle? in
            guard case let .path(path) = item.content, case let .rect(rectangle, _) = path.geometry else { return nil }

            return Rectangle(bounding: item.transform.apply(toCornersOf: rectangle))
        }
        #expect(drawn.count == count)
        for rectangle in drawn {
            #expect(isClose(rectangle, first.rectangle), "a shape is drawn at \(rectangle), the text is at \(first.rectangle)")
        }
    }

    // MARK: - Private
    private static let beside = #"{ "area": { "text": "Total", "padding": 14 }, "point": "right" }"#

    private static func anchor(
        of clip: ResolvedClip,
        by parents: ParentEvaluator,
        at time: Double
    ) -> Point {
        guard let box = clip.box else { return Point(x: 0, y: 0) }

        let space = parents.space(of: clip, at: time)
        return space.transform.apply(to: space.anchor(of: box, track: nil, at: time))
    }

    // "Total" on the frame shown at a media time.
    private static func text(
        at time: Double,
        growth: Double
    ) -> Rectangle {
        let total = Fixture.total
        let size = 1 + growth * time

        return Rectangle(
            center: Point(x: total.center.x + drift.x * time, y: total.center.y + drift.y * time),
            width: total.width * size,
            height: total.height * size
        )
    }

    private func planner(growth: Double) -> SequencePlanner {
        let lines = Fixture.screenFrameTimes.map { time in
            (from: time, lines: [RecognisedLine(text: "Total", rectangle: Self.text(at: time, growth: growth))])
        }

        return SequencePlanner(
            ocr: OCRTable(["/abs/screen.mp4": lines]),
            languages: nil,
            tracker: TrackerTable(
                frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes],
                drift: Self.drift,
                growth: growth
            ),
            shaper: Fixture.shaper,
            presets: Fixture.presets,
            library: Fixture.library
        )
    }

    private func isClose(
        _ point: Point,
        _ other: Point
    ) -> Bool {
        abs(point.x - other.x) < 1e-6 && abs(point.y - other.y) < 1e-6
    }

    private func isClose(
        _ rectangle: Rectangle,
        _ other: Rectangle
    ) -> Bool {
        isClose(Point(x: rectangle.x, y: rectangle.y), Point(x: other.x, y: other.y))
            && isClose(Point(x: rectangle.width, y: rectangle.height), Point(x: other.width, y: other.height))
    }
}
