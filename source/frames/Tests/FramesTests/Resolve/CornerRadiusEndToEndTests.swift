//
//  CornerRadiusEndToEndTests.swift
//  FramesTests
//
//  Created by JSilver on 11/24/26.
//

import Testing

@testable import Frames

// Each document is resolved, written, read back and evaluated, and its display list written and read back, so a
// `radius` of four corners is followed from the document to the item drawn (FRAMES-11 Shapes, FRAMES-19, FRAMES-20).
// The frame is 1920 wide, the base theme's `baseWidth`, so theme lengths are output pixels.
@Suite("Corner radius End To End Tests")
struct CornerRadiusEndToEndTests {
    // MARK: - Property
    private static let corners = CornerRadii(topLeft: 0, topRight: 20, bottomRight: 60, bottomLeft: 120)

    private let writer = ResolvedDocumentWriter()
    private let reader = ResolvedDocumentReader()
    private let evaluator = Evaluator()
    private let listWriter = DisplayListWriter()
    private let listReader = DisplayListReader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a rect, a media clip, a storyline clip and a rect mask each draw the four corners they write")
    func drawsFourCornersOfEachBox() throws {
        // Given
        let sut = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 4, "scale": 0.5, "radius": [0, 20, 60, 120] } ],
              "clips": [
                { "kind": "rect", "width": 400, "height": 300, "position": [960, 540], "fill": "accent", "radius": [0, 20, 60, 120], "at": [0, 4] },
                { "kind": "media", "media": "/abs/card.png", "at": [0, 4], "width": 400, "radius": [0, 20, 60, 120] },
                { "kind": "adjustment", "adjust": "frames/warm", "at": [0, 4], "mask": { "kind": "rect", "area": [0, 0, 400, 300], "radius": [0, 20, 60, 120] } } ] }
            """#)

        // When
        let list = try displayList(of: sut, at: 1)

        // Then
        #expect(list.items.flatMap(Self.pictures).map { "\($0.origin?.place ?? "none")" } == ["storyline[0]", "clips[1]"])
        #expect(list.items.flatMap(Self.pictures).map { $0.picture.radius } == [Self.corners, Self.corners])
        #expect(paths(in: list).map(\.geometry) == [.rect(Rectangle(x: 0, y: 0, width: 400, height: 300), radius: Self.corners)])
        let adjustment = try #require(list.items.last { $0.origin?.kind == "adjustment" })
        #expect(adjustment.mask.map(\.geometry) == [.rect(Rectangle(x: 0, y: 0, width: 400, height: 300), radius: Self.corners)])
    }

    @Test("a title's background and its run's highlight each draw the four corners their style writes")
    func drawsFourCornersOfTitleBoxes() throws {
        // Given
        let sut = try resolved(##"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "chip": { "size": 40,
                "background": { "color": "#000000", "padding": [8, 16], "radius": [0, 20, 60, 120] },
                "highlight": { "color": "#FF0000", "radius": [12, 0, 12, 0] } } } },
              "storyline": [ { "kind": "solid", "color": "#202020", "duration": 4 } ],
              "clips": [ { "kind": "title", "text": "Hi", "style": "chip", "at": [0, 4], "position": [960, 540] } ] }
            """##)

        // When
        let list = try displayList(of: sut, at: 1)

        // Then
        let glyphs = try #require(glyphs(in: list).first)
        #expect(glyphs.background?.radius == Self.corners)
        #expect(glyphs.runs.map { $0.highlight?.radius } == [CornerRadii(topLeft: 12, topRight: 0, bottomRight: 12, bottomLeft: 0)])
    }

    @Test("a keyframe that writes one radius may follow or lead one that writes four, each corner moving apart")
    func movesBetweenOneRadiusAndFour() throws {
        // Given
        let sut = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] }, "storyline": [ { "kind": "solid", "color": "#202020", "duration": 4 } ],
              "clips": [ { "kind": "rect", "width": 400, "height": 300, "position": [960, 540], "fill": "accent", "at": [0, 4],
                "keyframes": [ { "at": 0, "radius": 4 }, { "at": 2, "radius": [0, 4, 8, 12] }, { "at": 3, "radius": 10 } ] } ] }
            """#)

        // When
        let radii = try [0, 1, 2, 2.5].map { time in try radius(of: displayList(of: sut, at: time)) }

        // Then
        #expect(radii == [
            CornerRadii(4),
            CornerRadii(topLeft: 2, topRight: 4, bottomRight: 6, bottomLeft: 8),
            CornerRadii(topLeft: 0, topRight: 4, bottomRight: 8, bottomLeft: 12),
            CornerRadii(topLeft: 5, topRight: 7, bottomRight: 9, bottomLeft: 11)
        ])
    }

    @Test("a resolved document and a display list that write a radius as one number stop, since each writes its four radii")
    func refusesOneNumber() throws {
        // Given
        let sequence = try resolved(##"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "chip": { "size": 40, "background": { "color": "#000000", "radius": 6 }, "highlight": { "color": "#FF0000", "radius": 3 } } } },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 4, "radius": 12 } ],
              "clips": [
                { "kind": "rect", "width": 400, "height": 300, "position": [960, 540], "fill": "accent", "radius": 12, "at": [0, 4] },
                { "kind": "media", "media": "/abs/card.png", "at": [0, 4], "width": 400, "radius": 12 },
                { "kind": "title", "text": "Hi", "style": "chip", "at": [0, 4], "position": [960, 540] },
                { "kind": "adjustment", "adjust": "frames/warm", "at": [0, 4], "mask": { "shape": "rect", "area": [0, 0, 400, 300], "radius": 4 } } ] }
            """##)
        let list = evaluator.displayList(of: sequence, at: 1)
        let document = try JSONReader().read(writer.write(sequence))
        let written = try JSONReader().read(listWriter.write(list))
        let oneNumberDocument = Self.oneNumber(document)
        let oneNumberList = Self.oneNumber(written)

        // When, Then
        #expect(oneNumberDocument != document)
        #expect(oneNumberList != written)
        let documentError = #expect(throws: ModelError.self) { try reader.read(JSONWriter().write(oneNumberDocument)) }
        let listError = #expect(throws: ModelError.self) { try listReader.read(JSONWriter().write(oneNumberList)) }
        #expect(documentError?.description.contains("expected a list of 4 numbers, found") == true, "\(documentError?.description ?? "no error")")
        #expect(listError?.description.contains("expected a list of 4 numbers, found") == true, "\(listError?.description ?? "no error")")
    }

    @Test("a corner radius of another length than four in a display list stops, naming its place")
    func refusesOtherLengthInDisplayList() throws {
        // Given
        let sequence = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] }, "storyline": [ { "kind": "solid", "color": "#202020", "duration": 4 } ],
              "clips": [ { "kind": "rect", "width": 400, "height": 300, "position": [960, 540], "fill": "accent", "radius": [0, 20, 60, 120], "at": [0, 4] } ] }
            """#)
        let written = try JSONReader().read(listWriter.write(evaluator.displayList(of: sequence, at: 1)))
        let root = try #require(written.objectValue)
        let items = try #require(root["items"]?.arrayValue)
        let index = try #require(items.lastIndex { $0.objectValue?["geometry"]?.objectValue?["rect"] != nil })
        let item = try #require(items[index].objectValue)
        let rect = try #require(item["geometry"]?.objectValue?["rect"]?.objectValue)
        let geometry = JSONValue.object(JSONObject(members: [
            JSONMember(key: "rect", value: .object(rect.setting("radius", to: .array([.number(0), .number(20), .number(60)]))))
        ]))
        var changed = items
        changed[index] = .object(item.setting("geometry", to: geometry))

        // When, Then
        let error = #expect(throws: ModelError.self) {
            try listReader.read(JSONWriter().write(.object(root.setting("items", to: .array(changed)))))
        }
        #expect(error?.description.hasSuffix("expected a list of 4 numbers, found a list of 3") == true, "\(error?.description ?? "no error")")
        #expect(error?.description.hasPrefix("items[\(index)].geometry.rect.radius") == true, "\(error?.description ?? "no error")")
    }

    // MARK: - Private
    // The document resolved, written and read back, which must give the same sequence.
    private func resolved(_ document: String) throws -> ResolvedSequence {
        let sequence = try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
        let read = try reader.read(writer.write(sequence))
        #expect(read == sequence)

        return read
    }

    // The display list at `time`, written and read back, which must write the same text.
    private func displayList(
        of sequence: ResolvedSequence,
        at time: Double
    ) throws -> DisplayList {
        let list = evaluator.displayList(of: sequence, at: time)
        let read = try listReader.read(listWriter.write(list))
        #expect(listWriter.write(read) == listWriter.write(list))

        return read
    }

    // The pictures an item draws with the item that draws each, a nested list's among them.
    private static func pictures(in item: DisplayItem) -> [(origin: ItemOrigin?, picture: PictureItem)] {
        guard case let .picture(picture) = item.content else { return [] }

        switch picture.source {
        case let .displayList(list):
            return list.items.flatMap(pictures)

        default:
            return [(item.origin, picture)]
        }
    }

    private func paths(in list: DisplayList) -> [PathItem] {
        list.items.compactMap { item in
            guard case let .path(path) = item.content else { return nil }

            return path
        }
    }

    private func glyphs(in list: DisplayList) -> [GlyphsItem] {
        list.items.compactMap { item in
            guard case let .glyphs(glyphs) = item.content else { return nil }

            return glyphs
        }
    }

    // The corner radii of the one rect a list draws.
    private func radius(of list: DisplayList) throws -> CornerRadii {
        guard case let .rect(_, radius) = try #require(paths(in: list).first).geometry else {
            Issue.record("the path item is not a rect")
            return .zero
        }

        return radius
    }

    // `value` with each `radius` of four equal radii, alone or as the values of a keyframe list, written as one number.
    private static func oneNumber(_ value: JSONValue) -> JSONValue {
        switch value {
        case let .object(object):
            .object(JSONObject(members: object.members.map { member in
                JSONMember(key: member.key, value: member.key == "radius" ? oneRadius(member.value) : oneNumber(member.value))
            }))

        case let .array(elements):
            .array(elements.map(oneNumber))

        default:
            value
        }
    }

    private static func oneRadius(_ value: JSONValue) -> JSONValue {
        if let numbers = value.arrayValue?.compactMap(\.numberValue), numbers.count == 4, Set(numbers).count == 1 {
            return .number(numbers[0])
        }
        guard let keyframes = value.arrayValue?.compactMap(\.objectValue), keyframes.count == value.arrayValue?.count else {
            return oneNumber(value)
        }

        return .array(keyframes.map { keyframe in
            .object(keyframe["value"].map { keyframe.setting("value", to: oneRadius($0)) } ?? keyframe)
        })
    }
}
