//
//  ClipAreaEndToEndTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// Each document is resolved, written, read back and evaluated, so a clip area is followed from the document to the
// shape drawn from the named clip's box.
@Suite("Clip Area End To End Tests")
struct ClipAreaEndToEndTests {
    // MARK: - Property
    private let writer = ResolvedDocumentWriter()
    private let reader = ResolvedDocumentReader()
    private let evaluator = Evaluator()
    private let bar = ##"{ "id": "bar", "kind": "rect", "fill": "#000000", "at": [0, 4], "area": { "clip": "name", "padding": 24 } }"##

    // MARK: - Initializer
    // MARK: - Test
    @Test("a lower third bar is its title's box grown by the padding, so a longer name gives a wider bar")
    func growsBarWithName() throws {
        // Given
        let short = try resolved(clips: [title("Jo"), bar])
        let long = try resolved(clips: [title("Jane Doe-Harrington"), bar])

        // When
        let shortBar = try drawn("bar", in: short, at: 1)
        let longBar = try drawn("bar", in: long, at: 1)

        // Then
        let padding = 24 * MergedTheme.base.lengthScale(at: 1920)
        #expect(isClose(shortBar, try box(of: "name", in: short).grown(by: padding)))
        #expect(isClose(longBar, try box(of: "name", in: long).grown(by: padding)))
        #expect(longBar.width > shortBar.width)
    }

    @Test("a clip area's padding is a theme length, so it doubles on a frame twice as wide", arguments: [1920.0, 3840.0])
    func scalesPaddingWithFrame(width: Double) throws {
        // Given
        let sut = try resolved(clips: [title("Jane Doe"), bar], size: Size(width: width, height: width * 9 / 16))

        // When
        let drawn = try drawn("bar", in: sut, at: 1)

        // Then
        let box = try box(of: "name", in: sut)
        #expect(abs((drawn.width - box.width) - 48 * width / 1920) < 1e-9)
        #expect(isClose(drawn, box.grown(by: 24 * width / 1920)))
    }

    @Test("a note placed at its title's right edge by a point of a clip area sits there by its left edge")
    func placesNoteAtRightEdge() throws {
        // Given
        let note = ##"""
            { "id": "note", "kind": "rect", "fill": "#FF0000", "at": [0, 4], "width": 40, "height": 20, "anchor": "left",
              "position": { "area": { "clip": "name" }, "point": "right" } }
            """##
        let sut = try resolved(clips: [title("Jane Doe"), note])

        // When
        let drawn = try drawn("note", in: sut, at: 1)

        // Then
        let box = try box(of: "name", in: sut)
        #expect(isClose(drawn, Rectangle(x: box.x + box.width, y: box.center.y - 10, width: 40, height: 20)))
    }

    @Test("a bar parented to its title fits the title, follows its motion and scales its padding with it")
    func followsParentTitle() throws {
        // Given
        let title = #"""
            { "id": "name", "kind": "title", "text": "Jane Doe", "style": "title", "at": [0, 4], "anchor": "top-left", "scale": 2,
              "keyframes": [ { "at": 0, "position": [100, 600] }, { "at": 2, "position": [300, 600] } ] }
            """#
        let bar = ##"{ "kind": "rect", "fill": "#000000", "at": [0, 4], "parent": "name", "area": { "clip": "name", "padding": 10 } }"##
        let sut = try resolved(clips: [title, bar])

        // When
        let start = try drawn(at: 0, in: sut)
        let middle = try drawn(at: 1, in: sut)

        // Then
        let size = try #require(sut.clips[0].box?.size)
        let padding = 10 * MergedTheme.base.lengthScale(at: 1920)
        let grown = { (x: Double) in
            Rectangle(x: x, y: 600, width: size.width * 2, height: size.height * 2).grown(by: padding * 2)
        }
        #expect(isClose(start, grown(100)))
        #expect(isClose(middle, grown(200)))
    }

    @Test("a bar parented to its title follows it as it scales and turns in, its box carried by the title's transform")
    func followsParentEntrance() throws {
        // Given
        let title = #"""
            { "id": "name", "kind": "title", "text": "Jane Doe", "style": "title", "at": [0, 4], "position": [960, 900],
              "keyframes": [ { "at": 0, "scale": 0.5, "rotation": -30 }, { "at": 1, "scale": 1, "rotation": 0 } ] }
            """#
        let bar = ##"{ "id": "bar", "kind": "rect", "fill": "#000000", "at": [0, 4], "parent": "name", "area": { "clip": "name", "padding": 10 } }"##
        let sut = try resolved(clips: [title, bar])

        // When
        let drawn = try drawn("bar", in: sut, at: 0.1)
        let item = try #require(evaluator.displayList(of: sut, at: 0.1).items.first { $0.origin?.id == "name" })

        // Then
        let size = try #require(sut.clips[0].box?.size)
        let padding = 10 * MergedTheme.base.lengthScale(at: 1920)
        let box = Rectangle(x: 0, y: 0, width: size.width, height: size.height).grown(by: padding)
        #expect(item.transform != evaluator.displayList(of: sut, at: 2).items.first { $0.origin?.id == "name" }?.transform)
        #expect(isClose(drawn, Rectangle(bounding: item.transform.apply(toCornersOf: box))))
    }

    @Test("under a zoomed parent the padding is divided by the zoom, so the bar keeps its padding in output pixels")
    func keepsPaddingUnderZoomedParent() throws {
        // Given
        let zoom = ##"""
            { "id": "zoom", "kind": "rect", "fill": "#00000000", "at": [0, 4], "area": [0, 0, 960, 540], "anchor": "top-left",
              "scale": 2 }
            """##
        let title = #"{ "id": "name", "kind": "title", "text": "Jane Doe", "style": "title", "at": [0, 4], "parent": "zoom", "position": [100, 100], "anchor": "top-left" }"#
        let bar = ##"{ "id": "bar", "kind": "rect", "fill": "#000000", "at": [0, 4], "parent": "zoom", "area": { "clip": "name", "padding": 24 } }"##
        let sut = try resolved(clips: [zoom, title, bar])

        // When
        let drawn = try drawn("bar", in: sut, at: 1)

        // Then
        let size = try #require(sut.clips[1].box?.size)
        let padding = 24 * MergedTheme.base.lengthScale(at: 1920)
        #expect(isClose(drawn, Rectangle(x: 200, y: 200, width: size.width, height: size.height).grown(by: padding)))
    }

    @Test("a bar placed by a clip area keeps its named anchor and scales about that point of its box at each instant")
    func scalesAboutNamedAnchor() throws {
        // Given
        let bar = ##"""
            { "id": "bar", "kind": "rect", "fill": "#000000", "at": [0, 4], "area": { "clip": "name", "padding": 24 },
              "anchor": "left", "scale": 2 }
            """##
        let sut = try resolved(clips: [title("Jane Doe"), bar])

        // When
        let drawn = try drawn("bar", in: sut, at: 1)
        let written = try #require(try JSONReader().read(writer.write(sut)).objectValue?["clips"]?.arrayValue?.last?.objectValue)

        // Then
        let area = try box(of: "name", in: sut).grown(by: 24 * MergedTheme.base.lengthScale(at: 1920))
        #expect(written["anchor"] == .string("left"))
        #expect(isClose(drawn, Rectangle(x: area.x, y: area.center.y - area.height, width: area.width * 2, height: area.height * 2)))
    }

    @Test(
        "a bar follows its title's box at each instant as the title's padding, line height or tracking moves",
        arguments: [
            ##""paragraph": { "background": { "color": "#FF0000" } }, "keyframes": [ { "at": 0, "paragraph": { "background": { "padding": [0, 0] } } }, { "at": 2, "paragraph": { "background": { "padding": [10, 20] } } } ]"##,
            #""keyframes": [ { "at": 0, "paragraph": { "lineHeight": 50 } }, { "at": 2, "paragraph": { "lineHeight": 100 } } ]"#,
            #""keyframes": [ { "at": 0, "character": { "tracking": 0 } }, { "at": 2, "character": { "tracking": 200 } } ]"#
        ]
    )
    func followsKeyframedTitleBox(keys: String) throws {
        // Given
        let title = #"""
            { "id": "name", "kind": "title", "text": "Jane\nDoe", "style": "title", "at": [0, 4], "position": [200, 600], "anchor": "top-left",
              \#(keys) }
            """#
        let sut = try resolved(clips: [title, bar])

        // When
        let start = try drawn("bar", in: sut, at: 0)
        let middle = try drawn("bar", in: sut, at: 1)

        // Then
        let padding = 24 * MergedTheme.base.lengthScale(at: 1920)
        #expect(isClose(start, try box(of: "name", in: sut, at: 0).grown(by: padding)))
        #expect(isClose(middle, try box(of: "name", in: sut, at: 1).grown(by: padding)))
        #expect(!isClose(start, middle))
    }

    @Test("a bar parented to its title fits the title's box at each instant as its padding grows")
    func followsParentTitleBox() throws {
        // Given
        let title = #"""
            { "id": "name", "kind": "title", "text": "Jane Doe", "style": "title", "at": [0, 4], "position": [200, 600], "anchor": "top-left",
              "paragraph": { "background": { "color": "#FF0000" } },
              "keyframes": [ { "at": 0, "paragraph": { "background": { "padding": [0, 0] } } },
                             { "at": 2, "paragraph": { "background": { "padding": [10, 20] } } } ] }
            """#
        let bar = ##"{ "kind": "rect", "fill": "#000000", "at": [0, 4], "parent": "name", "area": { "clip": "name", "padding": 10 } }"##
        let sut = try resolved(clips: [title, bar])

        // When
        let start = try drawn(at: 0, in: sut)
        let middle = try drawn(at: 1, in: sut)

        // Then
        let padding = 10 * MergedTheme.base.lengthScale(at: 1920)
        #expect(isClose(start, try box(of: "name", in: sut, at: 0).grown(by: padding)))
        #expect(isClose(middle, try box(of: "name", in: sut, at: 1).grown(by: padding)))
        #expect(middle.width > start.width)
    }

    @Test(
        "a mask of a shape placed by its area or of an adjustment clip takes its clip area at each instant",
        arguments: [
            ##"{ "id": "cut", "kind": "rect", "fill": "#000000", "at": [0, 4], "area": [0, 0, 1920, 1080], "mask": { "kind": "rect", "area": { "clip": "name", "padding": 24 } } }"##,
            ##"{ "id": "cut", "kind": "adjustment", "adjust": "frames/warm", "at": [0, 4], "mask": [ { "kind": "rect", "area": { "clip": "name", "padding": 24 } } ] }"##
        ]
    )
    func masksByClipArea(clip: String) throws {
        // Given
        let sut = try resolved(clips: [movingTitle, clip])

        // When
        let start = try masked("cut", in: sut, at: 0)
        let middle = try masked("cut", in: sut, at: 1)

        // Then
        let size = try #require(sut.clips[0].box?.size)
        let padding = 24 * MergedTheme.base.lengthScale(at: 1920)
        #expect(isClose(start, Rectangle(x: 100, y: 600, width: size.width, height: size.height).grown(by: padding)))
        #expect(isClose(middle, Rectangle(x: 200, y: 600, width: size.width, height: size.height).grown(by: padding)))
    }

    @Test("a box mask centred on a point of a clip area and a path mask through its corners follow the named clip")
    func masksByClipPoints() throws {
        // Given
        let box = ##"""
            { "id": "box", "kind": "rect", "fill": "#000000", "at": [0, 4], "area": [0, 0, 1920, 1080],
              "mask": { "kind": "ellipse", "width": 40, "height": 20, "position": { "area": { "clip": "name" }, "point": "center" } } }
            """##
        let path = ##"""
            { "id": "path", "kind": "rect", "fill": "#000000", "at": [0, 4], "area": [0, 0, 1920, 1080],
              "mask": { "kind": "path", "points": [ { "vertex": { "area": { "clip": "name" }, "point": "top-left" } },
                                                     { "vertex": { "area": { "clip": "name" }, "point": "top-right" } },
                                                     { "vertex": { "area": { "clip": "name" }, "point": "bottom-left" } } ] } }
            """##
        let sut = try resolved(clips: [movingTitle, box, path])

        // When
        let ellipse = try masked("box", in: sut, at: 1)
        let triangle = try masked("path", in: sut, at: 1)

        // Then
        let size = try #require(sut.clips[0].box?.size)
        let named = Rectangle(x: 200, y: 600, width: size.width, height: size.height)
        #expect(isClose(ellipse, Rectangle(center: named.center, width: 40, height: 20)))
        #expect(isClose(triangle, named))
    }

    @Test("a mask's clip area is written as {clip, padding} and a point of one as {area, point}, and reads back the same")
    func roundTripsMaskClipArea() throws {
        // Given
        let clip = ##"""
            { "id": "cut", "kind": "rect", "fill": "#000000", "at": [0, 4], "area": [0, 0, 1920, 1080],
              "mask": [ { "kind": "rect", "area": { "clip": "name", "padding": 24 } },
                        { "kind": "path", "points": [ [0, 0], { "vertex": { "area": { "clip": "name" }, "point": "top-right" } }, [0, 10] ] } ] }
            """##
        let masks = try resolved(clips: [movingTitle, clip]).clips[1].mask
        let place = Place.root.appending(key: "clips").appending(index: 1).appending(key: "mask")

        // When
        let written = ResolvedValueWriter().masks(masks)
        let read = try ResolvedValueReader().masks(PlacedJSONValue(written, place: place, kind: "rect"))

        // Then
        let area = written.arrayValue?.first?.objectValue?["geometry"]?.objectValue?["rect"]
        let padding = 24 * MergedTheme.base.lengthScale(at: 1920)
        #expect(area?.arrayValue?.first?.objectValue?["value"]?.objectValue?["clip"] == .string("name"))
        #expect(area?.arrayValue?.first?.objectValue?["value"]?.objectValue?["padding"] == .number(padding))
        #expect(read == masks)
    }

    @Test("outside the named clip's window the area holds the box the clip has at the window's edge")
    func holdsOutsideNamedWindow() throws {
        // Given
        let title = #"""
            { "id": "name", "kind": "title", "text": "Jane Doe", "style": "title", "at": [1, 3], "anchor": "top-left",
              "keyframes": [ { "at": 0, "position": [100, 600] }, { "at": 2, "position": [300, 600] } ] }
            """#
        let sut = try resolved(clips: [title, bar])

        // When
        let before = try drawn("bar", in: sut, at: 0.5)
        let edge = try drawn("bar", in: sut, at: 1)

        // Then
        #expect(isClose(before, edge))
    }

    @Test("a keyframe span between numbers and a clip area moves towards the named clip's box at each instant")
    func interpolatesTowardsClipArea() throws {
        // Given
        let bar = ##"""
            { "id": "bar", "kind": "rect", "fill": "#000000", "at": [0, 4],
              "keyframes": [ { "at": 0, "area": [0, 0, 100, 100] }, { "at": 2, "area": { "clip": "name" } } ] }
            """##
        let sut = try resolved(clips: [title("Jane Doe"), bar])

        // When
        let middle = try drawn("bar", in: sut, at: 1)

        // Then
        let box = try box(of: "name", in: sut)
        let expected = Rectangle(x: box.x / 2, y: box.y / 2, width: (100 + box.width) / 2, height: (100 + box.height) / 2)
        #expect(isClose(middle, expected))
    }

    @Test(
        "a clip area that cannot be taken stops at its place",
        arguments: [
            (
                [#"{ "kind": "title", "text": "a", "style": "title", "at": [0, 4] }"#, ##"{ "kind": "rect", "fill": "#000000", "at": [0, 4], "area": { "clip": "nobody" } }"##],
                "clips[1].area"
            ),
            (
                [##"{ "kind": "rect", "fill": "#000000", "at": [0, 4], "area": { "clip": "back" } }"##],
                "clips[0].area"
            ),
            (
                [
                    ##"{ "id": "a", "kind": "rect", "fill": "#000000", "at": [0, 4], "area": { "clip": "b" } }"##,
                    #"{ "id": "b", "kind": "title", "text": "a", "style": "title", "at": [0, 4], "position": { "area": { "clip": "a" }, "point": "center" } }"#
                ],
                "clips[0]#a.area (rect): the clip areas come back to the box they start from: \"a\" > \"b\" > \"a\""
            ),
            (
                [
                    #"{ "id": "name", "kind": "title", "text": "a", "style": "title", "at": [0, 4], "parent": "card", "position": [0, 0] }"#,
                    #"{ "id": "card", "kind": "media", "media": "/abs/card.png", "at": [0, 4] }"#,
                    ##"{ "kind": "rect", "fill": "#000000", "at": [0, 4], "area": { "clip": "name" } }"##
                ],
                "clips[2].area"
            ),
            (
                [
                    #"{ "id": "name", "kind": "title", "text": "a", "style": "title", "at": [0, 4] }"#,
                    #"{ "kind": "media", "media": "/abs/card.png", "at": [0, 4], "crop": { "clip": "name" } }"#
                ],
                "clips[1].crop"
            ),
            (
                [
                    #"{ "id": "name", "kind": "title", "text": "a", "style": "title", "at": [0, 4] }"#,
                    #"{ "kind": "title", "text": "b", "style": "title", "at": [0, 4], "mask": { "kind": "rect", "area": { "clip": "name" } } }"#
                ],
                "clips[1].mask"
            ),
            (
                [
                    #"{ "id": "name", "kind": "title", "text": "a", "style": "title", "at": [0, 4] }"#,
                    ##"{ "kind": "rect", "fill": "#000000", "at": [0, 4], "area": [0, 0, 10, 10], "mask": { "kind": "rect", "area": { "clip": "nobody" } } }"##
                ],
                "clips[1].mask.area (rect): no clip of this document has the id \"nobody\""
            ),
            (
                [
                    #"{ "id": "name", "kind": "title", "text": "a", "style": "title", "at": [0, 4] }"#,
                    ##"{ "kind": "adjustment", "adjust": "frames/warm", "at": [0, 4], "mask": [ { "kind": "rect", "area": [0, 0, 10, 10] }, { "kind": "ellipse", "width": 10, "height": 10, "position": { "area": { "clip": "back" }, "point": "center" } } ] }"##
                ],
                "clips[1].mask[1].position.area"
            ),
            (
                [
                    #"{ "id": "name", "kind": "title", "text": "a", "style": "title", "at": [0, 4] }"#,
                    ##"{ "kind": "rect", "fill": "#000000", "at": [0, 4], "area": { "clip": "name", "text": "a" } }"##
                ],
                "clips[1].area"
            ),
            (
                [
                    #"{ "id": "name", "kind": "title", "text": "a", "style": "title", "at": [0, 4] }"#,
                    ##"{ "kind": "rect", "fill": "#000000", "at": [0, 4], "area": { "clip": "name", "padding": -1 } }"##
                ],
                "clips[1].area"
            )
        ]
    )
    func stopsClipArea(
        clips: [String],
        place: String
    ) throws {
        // When, Then
        let error = #expect(throws: (any Error).self) { try resolved(clips: clips) }
        let description = (error as? CustomStringConvertible)?.description ?? ""
        #expect(description.hasPrefix(place), "\(description)")
    }

    @Test("a storyline clip's position takes no clip area")
    func stopsClipAreaOnStoryline() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "storyline": [ { "kind": "media", "media": "/abs/card.png", "duration": 4, "position": { "area": { "clip": "name" }, "point": "center" } } ],
              "clips": [ { "id": "name", "kind": "title", "text": "a", "style": "title", "at": [0, 4] } ] }
            """#

        // When, Then
        let error = #expect(throws: (any Error).self) { try resolved(document) }
        let description = (error as? CustomStringConvertible)?.description ?? ""
        #expect(description.hasPrefix("storyline[0].position"), "\(description)")
    }

    // MARK: - Private
    private var movingTitle: String {
        #"""
            { "id": "name", "kind": "title", "text": "Jane Doe", "style": "title", "at": [0, 4], "anchor": "top-left",
              "keyframes": [ { "at": 0, "position": [100, 600] }, { "at": 2, "position": [300, 600] } ] }
            """#
    }

    private func title(_ text: String) -> String {
        #"{ "id": "name", "kind": "title", "text": "\#(text)", "style": "title", "at": [0, 4], "position": [200, 900], "anchor": "top-left" }"#
    }

    private func resolved(
        clips: [String],
        size: Size = Size(width: 1920, height: 1080)
    ) throws -> ResolvedSequence {
        try resolved(#"""
            { "kind": "sequence", "format": { "size": [\#(size.width), \#(size.height)] },
              "storyline": [ { "id": "back", "kind": "solid", "color": "#202020", "duration": 4 } ], "clips": [ \#(clips.joined(separator: ", ")) ] }
            """#)
    }

    // The document resolved, written and read back, which must give the same sequence.
    private func resolved(_ document: String) throws -> ResolvedSequence {
        let sequence = try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
        let read = try reader.read(writer.write(sequence))
        #expect(read == sequence)

        return read
    }

    // The box of an unparented clip with a box of its own in output pixels, before its transform.
    private func box(
        of id: String,
        in sequence: ResolvedSequence
    ) throws -> Rectangle {
        let box = try #require(sequence.clips.first { $0.id == id }?.box)
        let anchor = box.position.values[0].fixed

        return Rectangle(x: anchor.x - box.anchor.x, y: anchor.y - box.anchor.y, width: box.size.width, height: box.size.height)
    }

    // An unparented title's box with its background at `time`, in output pixels before its transform: its text box at
    // that instant about the anchor point resolve placed.
    private func box(
        of id: String,
        in sequence: ResolvedSequence,
        at time: Double
    ) throws -> Rectangle {
        let clip = try #require(sequence.clips.first { $0.id == id })
        let box = try #require(clip.box)
        guard case let .picture(.title(text), _) = clip.content else {
            Issue.record("the clip is a title")
            return Rectangle(x: 0, y: 0, width: 0, height: 0)
        }

        let anchor = box.position.values[0].fixed
        let drawn = text.box(at: SampleTime(time))
        return Rectangle(
            x: anchor.x - box.anchor.x + drawn.x,
            y: anchor.y - box.anchor.y + drawn.y,
            width: drawn.width,
            height: drawn.height
        )
    }

    // The rectangle a rect clip draws at `time`, in output pixels.
    private func drawn(
        _ id: String,
        in sequence: ResolvedSequence,
        at time: Double
    ) throws -> Rectangle {
        let item = try #require(evaluator.displayList(of: sequence, at: time).items.last { $0.origin?.id == id })
        guard case let .path(path) = item.content, case let .rect(rectangle, _) = path.geometry else {
            Issue.record("the clip draws no rect")
            return Rectangle(x: 0, y: 0, width: 0, height: 0)
        }

        return Rectangle(bounding: item.transform.apply(toCornersOf: rectangle))
    }

    // What the first mask of a clip's item cuts at `time`, bounded, in output pixels.
    private func masked(
        _ id: String,
        in sequence: ResolvedSequence,
        at time: Double
    ) throws -> Rectangle {
        let item = try #require(evaluator.displayList(of: sequence, at: time).items.last { $0.origin?.id == id })
        let mask = try #require(item.mask.first)
        switch mask.geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            return Rectangle(bounding: mask.transform.apply(toCornersOf: rectangle))

        case .path:
            return mask.geometry.bounds(carriedBy: mask.transform)
        }
    }

    // The rect the last path item draws at `time`, for a clip that has no id.
    private func drawn(
        at time: Double,
        in sequence: ResolvedSequence
    ) throws -> Rectangle {
        let item = try #require(evaluator.displayList(of: sequence, at: time).items.last { $0.origin?.kind == "rect" })
        guard case let .path(path) = item.content, case let .rect(rectangle, _) = path.geometry else {
            Issue.record("the clip draws no rect")
            return Rectangle(x: 0, y: 0, width: 0, height: 0)
        }

        return Rectangle(bounding: item.transform.apply(toCornersOf: rectangle))
    }

    private func isClose(
        _ rectangle: Rectangle,
        _ other: Rectangle
    ) -> Bool {
        [rectangle.x - other.x, rectangle.y - other.y, rectangle.width - other.width, rectangle.height - other.height]
            .allSatisfy { abs($0) < 1e-6 }
    }
}
