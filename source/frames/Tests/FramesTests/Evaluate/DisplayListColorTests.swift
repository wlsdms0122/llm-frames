//
//  DisplayListColorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/20/26.
//

import Testing

@testable import Frames

// What a display list carries for colour: the outermost list's colour space, every list's compositing, and each
// picture source's colour space and the peak the decoder tone maps an HDR picture of it to.
@Suite("Display List Color Tests")
struct DisplayListColorTests {
    // MARK: - Property
    private let sut = Evaluator()
    private let writer = DisplayListWriter()
    private let reader = DisplayListReader()

    private let presets = PresetTable(
        transitions: [
            "reveal": TransitionPreset(
                description: "",
                seconds: 1,
                over: .incoming,
                audio: .constantPower,
                incoming: Span(ease: .linear, keys: []),
                outgoing: nil,
                cover: Cover(source: .media("/abs/leak.mov"), span: Span(ease: .linear, keys: [])),
                matte: Matte(media: "/abs/matte.png", softness: 0.1, isInverted: false, ease: .linear)
            )
        ],
        animations: Fixture.presets.animations,
        filters: [:]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("the outermost list carries the sequence's colour space, and every list the compositing of its sequence")
    func carriesListColor() throws {
        // Given
        let resolved = try resolved(#"""
            { "kind": "sequence", "format": { "colorSpace": "rec2100-hlg", "compositing": "linear" }, "storyline": [
                { "kind": "media", "media": { "kind": "sequence", "format": { "size": [1080, 1920], "colorSpace": "srgb", "compositing": "encoded" },
                             "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] } } ] }
            """#)

        // When
        let list = sut.displayList(of: resolved, at: 0.5)

        // Then
        #expect(list.colorSpace == .rec2100HLG)
        #expect(list.compositing == .linear)
        let storyline = try #require(nestedList(of: list.items.first))
        #expect(storyline.colorSpace == nil)
        #expect(storyline.compositing == .linear)
        let compound = try #require(nestedList(of: storyline.items.first))
        #expect(compound.colorSpace == nil)
        #expect(compound.compositing == .encoded)
    }

    @Test(
        "a picture's source carries its clip's colour space, and the outermost sequence's peak where its clip tone maps",
        arguments: [
            ("srgb", "true", 203.0 as Double?),
            ("rec2100-pq", "true", 1000),
            ("rec2100-hlg", "true", 1000),
            ("srgb", "false", nil),
            ("rec2100-pq", "false", nil)
        ]
    )
    func carriesSourceColor(
        colorSpace: String,
        toneMap: String,
        targetPeak: Double?
    ) throws {
        // Given
        let resolved = try resolved(#"""
            { "kind": "sequence", "format": { "colorSpace": "\#(colorSpace)" }, "storyline": [
                { "kind": "media", "media": "/abs/run.mp4", "colorSpace": "rec709", "toneMap": \#(toneMap), "connected": [
                  { "kind": "media", "media": { "kind": "sequence", "format": { "size": [1080, 1350], "colorSpace": "srgb" },
                               "storyline": [ { "kind": "media", "media": "/abs/card.png", "duration": 1 } ] }, "at": [0, 1] } ] } ] }
            """#)

        // When
        let frames = frames(in: sut.displayList(of: resolved, at: 0.5))

        // Then
        #expect(frames.map(\.reading) == [
            .working(colorSpace: .rec709, targetPeak: targetPeak),
            .working(colorSpace: nil, targetPeak: ColorSpace(rawValue: colorSpace)?.peakLuminance)
        ])
    }

    @Test("a storyline clip and a media clip that write no toneMap are tone mapped to the outermost sequence's peak")
    func toneMapsByDefault() throws {
        // Given
        let resolved = try resolved(#"""
            { "kind": "sequence", "format": { "colorSpace": "rec2100-hlg" }, "storyline": [
                { "kind": "media", "media": "/abs/run.mp4", "connected": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1] } ] } ] }
            """#)

        // When
        let frames = frames(in: sut.displayList(of: resolved, at: 0.5))

        // Then
        #expect(resolved.storyline.map(\.isToneMapped) == [true])
        #expect(frames.map(\.reading) == [
            .working(colorSpace: nil, targetPeak: 1000),
            .working(colorSpace: nil, targetPeak: 1000)
        ])
    }

    @Test("a transition cover is tone mapped to the outermost sequence's peak, and its matte is read as an analysis picture")
    func carriesCoverAndMatteColor() throws {
        // Given
        let resolved = try resolved(#"""
            { "kind": "sequence", "format": { "colorSpace": "rec2100-pq" }, "storyline": [
                { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 3 }, { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 3, "transition": "reveal" } ] }
            """#)

        // When
        let list = sut.displayList(of: resolved, at: 3)

        // Then
        let pictures = list.items.compactMap(picture)
        let cover = try #require(pictures.last)
        guard case let .media(frame) = cover.source else {
            Issue.record("the cover shows no media")
            return
        }
        #expect(frame.reading == .working(colorSpace: nil, targetPeak: 1000))
        let matte = try #require(pictures.compactMap(\.matte).first)
        #expect(matte.frame.reading == .analysis(colorSpace: nil))

        let written = try #require(try JSONReader().read(writer.write(list)).objectValue)
        let items = written["items"]?.arrayValue?.compactMap(\.objectValue) ?? []
        let matteKeys = items.compactMap { $0["matte"]?.objectValue?.keys }.first
        #expect(matteKeys == ["source", "frame", "colorSpace", "progress", "softness", "invert"])
        // A list with no grain reads back with seed 0, so it is compared by the bytes it writes.
        #expect(try writer.write(reader.read(writer.write(list))) == writer.write(list))
    }

    @Test("the outermost list writes its colour space before its compositing, a nested list only its compositing")
    func writesListColor() throws {
        // Given
        let resolved = try resolved(#"""
            { "kind": "sequence", "format": { "colorSpace": "display-p3", "compositing": "linear" }, "storyline": [
                { "kind": "media", "media": "/abs/run.mp4", "colorSpace": "rec709", "toneMap": false } ] }
            """#)
        let list = sut.displayList(of: resolved, at: 0.5)

        // When
        let written = try #require(try JSONReader().read(writer.write(list)).objectValue)

        // Then
        #expect(written.keys == ["displayList", "size", "background", "colorSpace", "peak", "compositing", "items"])
        #expect(written["colorSpace"] == .string("display-p3"))
        #expect(written["compositing"] == .string("linear"))
        let nested = try #require(written["items"]?.arrayValue?.first?.objectValue?["source"]?.objectValue?["list"]?.objectValue)
        #expect(nested.keys == ["size", "background", "compositing", "items"])
        let source = try #require(nested["items"]?.arrayValue?.first?.objectValue?["source"]?.objectValue)
        #expect(source.keys == ["kind", "media", "frame", "colorSpace", "targetPeak"])
        #expect(source["colorSpace"] == .string("rec709"))
        #expect(source["targetPeak"] == .null)
        // A list with no grain reads back with seed 0, so it is compared by the bytes it writes.
        #expect(try writer.write(reader.read(writer.write(list))) == writer.write(list))
    }

    @Test(
        "a list without its colour space, a nested list with one and a target peak not above 0 stop",
        arguments: [
            (0, #"top level (display list): missing key "colorSpace""#),
            (1, #"items[0].source.list (display list): unknown key "colorSpace""#),
            (2, "a target peak is above 0 cd/m², found 0")
        ]
    )
    func refusesUnreadableColor(
        change: Int,
        message: String
    ) throws {
        // Given
        let resolved = try resolved(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }"#)
        let root = try #require(try JSONReader().read(writer.write(sut.displayList(of: resolved, at: 0.5))).objectValue)
        let item = try #require(root["items"]?.arrayValue?.first?.objectValue)
        let source = try #require(item["source"]?.objectValue)
        let nested = try #require(source["list"]?.objectValue)
        let inner = try #require(nested["items"]?.arrayValue?.first?.objectValue)
        let innerSource = try #require(inner["source"]?.objectValue)
        let changed = switch change {
        case 0:
            edited(root, nested: nil)

        case 1:
            edited(root, nested: nested.setting("colorSpace", to: .string("srgb")))

        default:
            edited(
                root,
                nested: nested.setting("items", to: .array([.object(inner.setting(
                    "source",
                    to: .object(innerSource.setting("targetPeak", to: .number(0)))
                ))]))
            )
        }

        // When
        let error = #expect(throws: (any Error).self) { try reader.read(changed) }

        // Then
        #expect(error.map { "\($0)" }?.contains(message) == true)
    }

    // MARK: - Private
    // The list with its outermost colour space removed where `nested` is nil, and otherwise its first item's nested
    // list replaced by `nested`.
    private func edited(
        _ root: JSONObject,
        nested: JSONObject?
    ) -> JSONValue {
        guard let nested else { return .object(JSONObject(members: root.members.filter { $0.key != "colorSpace" })) }

        let item = root["items"]?.arrayValue?.first?.objectValue ?? JSONObject()
        let source = item["source"]?.objectValue ?? JSONObject()
        let changed = item.setting("source", to: .object(source.setting("list", to: .object(nested))))
        return .object(root.setting("items", to: .array([.object(changed)])))
    }

    private func resolved(_ document: String) throws -> ResolvedSequence {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: presets,
            shaper: Fixture.shaper,
            library: Fixture.library
        )
        return try ResolvedSequence(plan: planner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    private func picture(_ item: DisplayItem) -> PictureItem? {
        guard case let .picture(picture) = item.content else { return nil }

        return picture
    }

    private func nestedList(of item: DisplayItem?) -> DisplayList? {
        guard let item, case let .displayList(list)? = picture(item)?.source else { return nil }

        return list
    }

    // Every media frame a picture shows, nested lists included, bottom first.
    private func frames(in list: DisplayList) -> [MediaFrame] {
        list.items.compactMap(picture).flatMap { picture -> [MediaFrame] in
            switch picture.source {
            case let .media(frame):
                [frame]

            case let .displayList(nested):
                frames(in: nested)
            }
        }
    }
}
