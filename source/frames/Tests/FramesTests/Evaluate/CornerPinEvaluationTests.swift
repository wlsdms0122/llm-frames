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

    // A scale of 2 throughout a two second entrance, and a transition that slides the incoming clip in from one frame
    // width to the right.
    private static let presets = PresetTable(
        transitions: Fixture.presets.transitions.merging(["mine/slide": TransitionPreset(
            description: "",
            seconds: 1,
            over: .incoming,
            audio: .constantPower,
            incoming: Span(ease: .linear, keys: [SpanKey(t: 0, values: [.x: 1]), SpanKey(t: 1, values: [.x: 0])]),
            outgoing: nil,
            cover: nil,
            matte: nil
        )]) { $1 },
        animations: Fixture.presets.animations.merging(["mine/grow": AnimationPreset(
            description: "",
            entrance: AnimationSpan(length: 2, span: Span(ease: .linear, keys: [
                SpanKey(t: 0, values: [.scale: 2]),
                SpanKey(t: 1, values: [.scale: 2])
            ])),
            loop: nil,
            exit: nil
        )]) { $1 },
        filters: Fixture.presets.filters
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

    @Test("a clip with a corner pin draws nothing at an instant its keyframed box has no width, and draws on either side")
    func drawsNothingWithoutBoxArea() throws {
        // Given
        // The ease [0, 4, 1, 4] is 3.125 half way, so the width from 100 to 50 overshoots to -56.25 at 1, and is above
        // 0 near either keyframe.
        let sequence = try resolved(#"""
            { "id": "card", "shape": "rect", "fill": "accent", "height": 50, "at": [0, 4], "cornerPin": \#(Self.pin), "keyframes": [
              { "at": 0, "width": 100, "ease": [0, 4, 1, 4] }, { "at": 2, "width": 50 } ] }
            """#)

        // When
        let before = sut.displayList(of: sequence, at: 0.01)
        let flat = sut.displayList(of: sequence, at: 1)
        let after = sut.displayList(of: sequence, at: 1.99)

        // Then
        #expect(before.items.contains { $0.origin?.id == "card" })
        #expect(!flat.items.contains { $0.origin?.id == "card" })
        #expect(after.items.contains { $0.origin?.id == "card" })
    }

    @Test("a clip with a corner pin and an animation scales on its plane, about the centre of its box, and its group in its parent's space is not moved")
    func scalesOnPlane() throws {
        // Given
        let sequence = try resolved(
            document: #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ { "id": "card", "media": "/abs/page.png", "width": 300, "at": [0, 4], "cornerPin": \#(Self.pin), "animation": "mine/grow" } ] }"#,
            presets: Self.presets
        )

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        // The box is [0, 0, 300, 240], and the nested list puts its top left at the picture's rectangle's origin.
        let group = try #require(list.items.last)
        guard case let .picture(picture) = group.content, case let .displayList(nested) = picture.source else {
            Issue.record("the group is not a picture of a nested list")
            return
        }
        let item = try #require(nested.items.first)
        let origin = try #require(picture.rectangle)
        let inBox = { (point: Point) in
            let carried = item.transform.apply(to: point)
            return Point(x: carried.x - origin.x, y: carried.y - origin.y)
        }
        #expect(group.transform == .identity)
        #expect(picture.cornerPin == Self.quad)
        #expect(inBox(Point(x: 150, y: 120)) == Point(x: 150, y: 120))
        #expect(inBox(Point(x: 0, y: 0)) == Point(x: -150, y: -120))
    }

    @Test("a storyline clip's transition moves its pinned picture in the frame's space, on its outer item, and leaves its corner pin as written")
    func movesStorylineTransitionInFrame() throws {
        // Given
        let sequence = try resolved(
            document: #"""
                { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 2 },
                  { "id": "shot", "media": "/abs/run.mp4", "in": 0, "out": 2, "transition": "mine/slide", "cornerPin": \#(Self.pin) } ] }
                """#,
            presets: Self.presets
        )

        // When
        let list = sut.displayList(of: sequence, at: 2)

        // Then
        let outer = try #require(list.items.first { storylineCornerPin(in: [$0]) != nil })
        #expect(storylineCornerPin(in: [outer]) == Self.quad)
        #expect(outer.transform.tx > 0)
        #expect(outer.transform.ty == 0)
    }

    @Test("a clip with a corner pin applies its filter to the item inside its group, on its plane, and its group carries none")
    func filtersOnPlane() throws {
        // Given
        let sequence = try resolved(#"{ "id": "card", "media": "/abs/page.png", "width": 300, "at": [0, 4], "cornerPin": \#(Self.pin), "filter": "mine/grade" }"#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let group = try #require(list.items.last)
        guard case let .picture(picture) = group.content, case let .displayList(nested) = picture.source,
              case let .picture(inner) = nested.items.first?.content else {
            Issue.record("the group is not a picture of a nested list of a picture")
            return
        }
        #expect(picture.filter.isEmpty)
        #expect(!inner.filter.isEmpty)
    }

    @Test("a cropped media clip with a corner pin pins its box by its width and crop, the crop drawn inside its group")
    func pinsCroppedBox() throws {
        // Given
        let sequence = try resolved(#"{ "id": "card", "media": "/abs/page.png", "width": 300, "crop": [100, 0, 500, 400], "at": [0, 4], "cornerPin": \#(Self.pin) }"#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let group = try #require(list.items.last)
        guard case let .picture(picture) = group.content, case let .displayList(nested) = picture.source,
              case let .picture(inner) = nested.items.first?.content else {
            Issue.record("the group is not a picture of a nested list of a picture")
            return
        }
        #expect(picture.cornerPin == Self.quad)
        #expect(picture.destination == Rectangle(x: 0, y: 0, width: 300, height: 240))
        #expect(inner.rectangle == Rectangle(x: 100, y: 0, width: 500, height: 400))
        #expect(inner.destination == Rectangle(x: 0, y: 0, width: 300, height: 240))
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

    @Test("a corner pin holding a clip area draws nothing at an instant the named clip's box makes it not strictly convex, and draws on either side")
    func drawsNothingWhereClipAreaFolds() throws {
        // Given
        // The bottom right corner is that of "bar", at x = 500 at 0 and 2 and at x = -300 at 1, so it passes the bottom
        // left corner at 0.5 and 1.5 and the corner pin is not strictly convex between them.
        let sequence = try resolved(#"""
            { "id": "bar", "shape": "rect", "fill": "accent", "at": [0, 4], "keyframes": [
              { "at": 0, "area": [400, 300, 100, 100], "ease": "linear" },
              { "at": 1, "area": [-400, 300, 100, 100], "ease": "linear" },
              { "at": 2, "area": [400, 300, 100, 100] } ] },
            { "id": "card", "media": "/abs/page.png", "width": 300, "at": [0, 4],
              "cornerPin": [[100, 100], [500, 100], { "area": { "clip": "bar" }, "point": "bottom-right" }, [100, 400]] }
            """#)

        // When
        let before = sut.displayList(of: sequence, at: 0.25)
        let folded = sut.displayList(of: sequence, at: 1)
        let after = sut.displayList(of: sequence, at: 1.75)

        // Then
        #expect(before.items.contains { $0.origin?.id == "card" })
        #expect(!folded.items.contains { $0.origin?.id == "card" })
        #expect(after.items.contains { $0.origin?.id == "card" })
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

    @Test("a title with a corner pin, a background padding and a mask has its mask in its glyphs item's coordinates, its text box, as without a corner pin, and the text box at the padding in its box")
    func carriesTitleMasksWithGlyphs() throws {
        // Given
        let title = ##""title": "ab", "style": "title", "at": [0, 4], "paragraph": { "background": { "color": "#FF0000", "padding": [8, 12] } }, "mask": [ { "shape": "rect", "area": [0, 0, 20, 20] } ]"##
        let pinned = try resolved(#"{ "id": "card", \#(title), "cornerPin": \#(Self.pin) }"#)
        let placed = try resolved(#"{ "id": "card", \#(title), "position": [400, 300] }"#)

        // When
        let list = sut.displayList(of: pinned, at: 1)
        let unpinned = sut.displayList(of: placed, at: 1)

        // Then
        guard
            case let .picture(picture) = list.items.last?.content,
            case let .displayList(nested) = picture.source,
            let item = nested.items.first,
            let rectangle = picture.rectangle
        else {
            Issue.record("the group is not a picture of a nested list")
            return
        }
        let unpinnedItem = try #require(unpinned.items.last)
        let mask = try #require(item.mask.first)
        let unpinnedMask = try #require(unpinnedItem.mask.first)
        // The group's rect is B in the list, so B's top left lies at the rect's origin there.
        let corner = mask.transform.apply(to: Point(x: 0, y: 0))
        // The padding of [8, 12] is 4.5 by 6.75 output pixels in a frame 1080 pixels wide.
        #expect(item.mask.count == 1)
        #expect(isClose(mask.transform, item.transform))
        #expect(isClose(unpinnedMask.transform, unpinnedItem.transform))
        #expect(abs(corner.x - rectangle.x - 6.75) < 1e-9 && abs(corner.y - rectangle.y - 4.5) < 1e-9)
    }

    @Test("a tracked corner pin brings back each keyframe of numbers at its own time, though another keyframe holds a clip area, so it draws at that time what it writes")
    func bringsBackNumberKeyframeBesideClipArea() throws {
        // Given
        // From media second 0.1 the target [0, 0, 100, 100] is seen as a trapezoid, so the track's homography there is
        // not its motion. The untracked clip draws the same four points as the tracked one's keyframe at 0.5.
        let target = Quad(Rectangle(x: 0, y: 0, width: 100, height: 100))
        let far = Quad(topLeft: Point(x: 0, y: 0), topRight: Point(x: 100, y: 0), bottomRight: Point(x: 60, y: 50), bottomLeft: Point(x: 40, y: 50))
        let quads = [(0.0, target)] + (1...10).map { (Double($0) / 10, far) }
        let track = QuadTrackerTable(base: target, quads: quads).data(atMediaTime: 0)
        let corners = ["top-left", "top-right", "bottom-right", "bottom-left"]
            .map { #"{ "area": { "clip": "bar" }, "point": "\#($0)" }"# }
            .joined(separator: ", ")
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "out": 1, "connected": [
                { "id": "bar", "shape": "rect", "fill": "accent", "area": [20, 20, 60, 30], "parent": "screen", "at": [0, 1] },
                { "id": "tracked", "media": "/abs/card.png", "parent": "screen", "at": [0, 1], "width": 300, "track": \#(track),
                  "keyframes": [ { "at": 0.5, "cornerPin": [[10, 10], [90, 10], [90, 40], [10, 40]] },
                                 { "at": 0.9, "cornerPin": [\#(corners)] } ] },
                { "id": "still", "media": "/abs/card.png", "parent": "screen", "at": [0, 1], "width": 300,
                  "cornerPin": [[10, 10], [90, 10], [90, 40], [10, 40]] } ] } ] }
            """#
        let sequence = try resolved(document: document)

        // When
        let list = sut.displayList(of: sequence, at: 0.5)

        // Then
        let drawn = { (id: String) throws -> [Point] in
            let item = try #require(list.items.first { $0.origin?.id == id })
            guard case let .picture(picture) = item.content else {
                Issue.record("the group is not a picture")
                return []
            }

            return try #require(picture.cornerPin).corners.map(item.transform.apply(to:))
        }
        let tracked = try drawn("tracked")
        let still = try drawn("still")
        #expect(tracked.count == 4)
        #expect(zip(tracked, still).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 })
    }

    @Test("a tracked corner pin keyframe that holds a clip area brings back its other corners at its own time and carries the clip area's corner by the track's homography")
    func bringsBackCornersBesideClipAreaCorner() throws {
        // Given
        // From media second 0.1 the target [0, 0, 100, 100] is seen as a trapezoid, whose homography takes (x, y) to
        // ((x + 2y) / w, 2.5y / w) with w = 1 + 0.04y. The bottom right of "bar" is (80, 50) on the track's frame, which
        // the homography takes to (60, 125 / 3).
        let target = Quad(Rectangle(x: 0, y: 0, width: 100, height: 100))
        let far = Quad(topLeft: Point(x: 0, y: 0), topRight: Point(x: 100, y: 0), bottomRight: Point(x: 60, y: 50), bottomLeft: Point(x: 40, y: 50))
        let quads = [(0.0, target)] + (1...10).map { (Double($0) / 10, far) }
        let track = QuadTrackerTable(base: target, quads: quads).data(atMediaTime: 0)
        let pin = #"[[10, 10], [90, 10], { "area": { "clip": "bar" }, "point": "bottom-right" }, [10, 40]]"#
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "out": 1, "connected": [
                { "id": "bar", "shape": "rect", "fill": "accent", "area": [20, 20, 60, 30], "parent": "screen", "at": [0, 1] },
                { "id": "tracked", "media": "/abs/card.png", "parent": "screen", "at": [0, 1], "width": 300, "track": \#(track),
                  "keyframes": [ { "at": 0.5, "cornerPin": \#(pin) }, { "at": 0.9, "cornerPin": \#(pin) } ] } ] } ] }
            """#
        let sequence = try resolved(document: document)

        // When
        let list = sut.displayList(of: sequence, at: 0.5)

        // Then
        let item = try #require(list.items.first { $0.origin?.id == "tracked" })
        guard case let .picture(picture) = item.content else {
            Issue.record("the group is not a picture")
            return
        }
        let drawn = try #require(picture.cornerPin).corners.map(item.transform.apply(to:))
        let expected = [Point(x: 10, y: 10), Point(x: 90, y: 10), Point(x: 60, y: 125.0 / 3), Point(x: 10, y: 40)]
        #expect(drawn.count == 4)
        #expect(zip(drawn, expected).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 })
    }

    @Test("a tracked corner pin draws nothing where all four corners lie beyond the horizon of the track's homography, though the corner pin it would carry is strictly convex")
    func drawsNothingBeyondHorizon() throws {
        // Given
        // From media second 0.1 the target [0, 0, 100, 100] is seen as a trapezoid, whose homography has the horizon
        // y = -25 and w below 0 above it. The corner pin [10, -60, 80, 20] on the track's frame lies wholly there, and
        // the homography would carry it to the strictly convex [78.57, 107.14], [21.43, 107.14], [-16.67, 166.67],
        // [116.67, 166.67], the plane seen from behind.
        let target = Quad(Rectangle(x: 0, y: 0, width: 100, height: 100))
        let far = Quad(topLeft: Point(x: 0, y: 0), topRight: Point(x: 100, y: 0), bottomRight: Point(x: 60, y: 50), bottomLeft: Point(x: 40, y: 50))
        let quads = [(0.0, target)] + (1...10).map { (Double($0) / 10, far) }
        let track = QuadTrackerTable(base: target, quads: quads).data(atMediaTime: 0)
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "out": 1, "connected": [
                { "id": "pinned", "media": "/abs/card.png", "parent": "screen", "at": [0, 1], "width": 300, "track": \#(track),
                  "cornerPin": [[10, -60], [90, -60], [90, -40], [10, -40]] } ] } ] }
            """#
        let sequence = try resolved(document: document)

        // When
        let onTarget = sut.displayList(of: sequence, at: 0.05)
        let behind = sut.displayList(of: sequence, at: 0.5)

        // Then
        #expect(onTarget.items.contains { $0.origin?.id == "pinned" })
        #expect(!behind.items.contains { $0.origin?.id == "pinned" })
    }

    @Test("a corner pin with motionBlur keyframed to move gives its group in every sample at that sample's corner pin, and the samples read back")
    func movesCornerPinInEverySample() throws {
        // Given
        let sequence = try resolved(document: #"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
              { "id": "card", "media": "/abs/page.png", "width": 300, "at": [0, 4], "motionBlur": true, "keyframes": [
                { "at": 0, "cornerPin": [[100, 100], [500, 100], [500, 400], [100, 400]], "ease": "linear" },
                { "at": 2, "cornerPin": [[300, 100], [700, 100], [700, 400], [300, 400]] } ] } ] }
            """#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let samples = try #require(list.samples)
        let pins = try samples.map { try cornerPin(of: "card", in: $0) }
        #expect(samples.count == 16)
        #expect(pins.allSatisfy { $0.isStrictlyConvex })
        #expect(pins.first != pins.last)
        #expect(try DisplayListReader().read(DisplayListWriter().write(list)).samples?.count == 16)
    }

    @Test("a tracked corner pin with motionBlur that crosses its horizon inside the exposure gives its group in every sample, four points at [0, 0] where it draws nothing, and the samples read back")
    func keepsCornerPinAcrossHorizonInEverySample() throws {
        // Given
        // From media second 0.1 the target [0, 0, 100, 100] is seen as a trapezoid, whose homography takes (x, y) to
        // ((x + 2y) / w, 2.5y / w) with w = 1 + 0.04y, so its horizon is y = -25 on the track's frame. The corner pin
        // goes from beyond the horizon at 0 to [10, 0, 80, 25] on that frame at 1, so its top corners cross the horizon
        // at 0.58333, between the instants 0.583125 and 0.584375 of the frame at 0.57.
        let target = Quad(Rectangle(x: 0, y: 0, width: 100, height: 100))
        let far = Quad(topLeft: Point(x: 0, y: 0), topRight: Point(x: 100, y: 0), bottomRight: Point(x: 60, y: 50), bottomLeft: Point(x: 40, y: 50))
        let track = QuadTrackerTable(base: target, quads: [(0.0, target)] + (1...10).map { (Double($0) / 10, far) }).data(atMediaTime: 0)
        let document = { (isMotionBlurred: Bool) in
            #"""
                { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
                  "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "out": 1, "connected": [
                    { "id": "pinned", "media": "/abs/card.png", "parent": "screen", "at": [0, 1], "width": 300,
                      "motionBlur": \#(isMotionBlurred), "track": \#(track),
                      "keyframes": [ { "at": 0, "cornerPin": [[10, -60], [90, -60], [90, -40], [10, -40]], "ease": "linear" },
                                     { "at": 1, "cornerPin": [[10, 0], [90, 0], [70, 31.25], [30, 31.25]] } ] } ] } ] }
                """#
        }
        let blurred = try resolved(document: document(true))
        let sharp = try resolved(document: document(false))

        // When
        let list = sut.displayList(of: blurred, at: 0.57)

        // Then
        let samples = try #require(list.samples)
        let pins = try samples.map { try cornerPin(of: "pinned", in: $0) }
        let none = Quad(Rectangle(x: 0, y: 0, width: 0, height: 0))
        #expect(samples.count == 16)
        #expect(pins.prefix(11).allSatisfy { $0 == none })
        #expect(pins.suffix(5).allSatisfy { $0.isStrictlyConvex })
        #expect(!sut.displayList(of: sharp, at: 0.57).items.contains { $0.origin?.id == "pinned" })
        #expect(try DisplayListReader().read(DisplayListWriter().write(list)).samples?.count == 16)
    }

    @Test("a storyline clip with motionBlur whose corner pin folds inside the exposure gives its group in every sample, four points at [0, 0] where it draws nothing")
    func keepsStorylineGroupInEverySample() throws {
        // Given
        // The top corners cross at 1 and the bottom ones at 1.333, so the corner pin is not strictly convex between them.
        // The frame at 0.99 has its samples at 0.990625 to 1.009375, eight on each side of 1.
        let sequence = try resolved(document: #"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "storyline": [ { "id": "shot", "media": "/abs/run.mp4", "motionBlur": true, "keyframes": [
                { "at": 0, "cornerPin": [[100, 100], [500, 100], [500, 400], [100, 400]], "ease": "linear" },
                { "at": 2, "cornerPin": [[500, 100], [100, 100], [200, 400], [400, 400]] } ] } ] }
            """#)

        // When
        let list = sut.displayList(of: sequence, at: 0.99)

        // Then
        let samples = try #require(list.samples)
        let pins = samples.map(storylineCornerPin(in:))
        #expect(samples.count == 16)
        #expect(pins.prefix(8).allSatisfy { $0?.isStrictlyConvex == true })
        #expect(pins.suffix(8).allSatisfy { $0 == .collapsed })
        #expect(try DisplayListReader().read(DisplayListWriter().write(list)).samples?.count == 16)
    }

    @Test("a tracked corner pin with motionBlur is carried by the homography of the media frame of T in every sample, though the exposure crosses into a frame whose quad differs")
    func carriesTrackedCornerPinAtT() throws {
        // Given
        // `/abs/screen.mp4` shows a new frame every 0.1 seconds. From 0.1 to 0.9 the target [0, 0, 100, 100] is seen as
        // one trapezoid and from 1 as a narrower one, so the two homographies differ and neither is a similarity. The
        // exposure of the frame at 0.99 runs from 0.990625 to 1.009375, across the media frames at 0.9 and 1.
        let target = Quad(Rectangle(x: 0, y: 0, width: 100, height: 100))
        let near = Quad(topLeft: Point(x: 0, y: 0), topRight: Point(x: 100, y: 0), bottomRight: Point(x: 90, y: 90), bottomLeft: Point(x: 10, y: 90))
        let far = Quad(topLeft: Point(x: 0, y: 0), topRight: Point(x: 100, y: 0), bottomRight: Point(x: 60, y: 50), bottomLeft: Point(x: 40, y: 50))
        let quads = [(0.0, target)] + (1...20).map { (Double($0) / 10, $0 < 10 ? near : far) }
        let track = QuadTrackerTable(base: target, quads: quads).data(atMediaTime: 0)
        let sequence = try resolved(document: #"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "out": 2, "connected": [
                { "id": "pinned", "media": "/abs/card.png", "parent": "screen", "at": [0, 2], "width": 300, "motionBlur": true,
                  "track": \#(track), "cornerPin": [[10, 10], [90, 10], [90, 40], [10, 40]] } ] } ] }
            """#)

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 0.99).samples)

        // Then
        let atT = sut.displayListWithoutMotionBlur(of: sequence, at: 0.99).items
        let next = sut.displayListWithoutMotionBlur(of: sequence, at: 1).items
        let drawnAtT = try drawnCornerPin(of: "pinned", in: atT)
        let drawnNext = try drawnCornerPin(of: "pinned", in: next)
        #expect(samples.count == 16)
        #expect(samples.allSatisfy { $0 == atT })
        #expect(zip(drawnAtT, drawnNext).contains { abs($0.x - $1.x) > 1 || abs($0.y - $1.y) > 1 })
    }

    // MARK: - Private
    // The corner pin of the one group in the inner list of the storyline item first in `items`.
    private func storylineCornerPin(in items: [DisplayItem]) -> Quad? {
        guard
            case let .picture(storyline) = items.first?.content,
            case let .displayList(inner) = storyline.source,
            inner.items.count == 1,
            case let .picture(group) = inner.items.first?.content
        else {
            return nil
        }

        return group.cornerPin
    }

    // The corner pin of the one group the clip named `id` draws in `items`.
    private func cornerPin(
        of id: String,
        in items: [DisplayItem]
    ) throws -> Quad {
        let groups = items.filter { $0.origin?.id == id }
        #expect(groups.count == 1)
        guard case let .picture(picture) = try #require(groups.first).content else {
            Issue.record("the group is not a picture")
            return Quad(Rectangle(x: 0, y: 0, width: 0, height: 0))
        }

        return try #require(picture.cornerPin)
    }

    // The corners the clip named `id` draws its group at in `items`, in the pixels of the list.
    private func drawnCornerPin(
        of id: String,
        in items: [DisplayItem]
    ) throws -> [Point] {
        let item = try #require(items.first { $0.origin?.id == id })

        return try cornerPin(of: id, in: items).corners.map(item.transform.apply(to:))
    }

    private func isClose(
        _ transform: AffineTransform,
        _ other: AffineTransform
    ) -> Bool {
        [transform.a - other.a, transform.b - other.b, transform.c - other.c, transform.d - other.d,
         transform.tx - other.tx, transform.ty - other.ty]
            .allSatisfy { abs($0) < 1e-9 }
    }

    private func resolved(
        document: String,
        presets: any PresetProvider
    ) throws -> ResolvedSequence {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: presets,
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
