//
//  NullClipEndToEndTests.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

import Testing

@testable import Frames

// Each document is resolved, written, read back and evaluated, so a null is followed from the document to what its
// children and the clip areas that name it draw. A null is compared with a rect placed the same way, which carries its
// children and gives its box as a null does and draws a picture of its own besides.
@Suite("Null Clip End To End Tests")
struct NullClipEndToEndTests {
    // MARK: - Property
    private static let rect = ##""shape": "rect", "fill": "#FF0000", "animation": "none""##

    private let writer = ResolvedDocumentWriter()
    private let reader = ResolvedDocumentReader()
    private let evaluator = Evaluator()
    private let child = ##"{ "id": "child", "shape": "rect", "fill": "#00FF00", "at": [0, 4], "parent": "carrier", "width": 40, "height": 20, "position": [50, 30] }"##

    // MARK: - Initializer
    // MARK: - Test
    @Test("a null given by width and height resolves to a null entry with its box and transform, and reads back equal")
    func resolvesBoxForm() throws {
        // Given
        let carrier = #"{ "id": "carrier", "null": true, "at": [0, 4], "width": 200, "height": 100, "position": [600, 400], "rotation": 30 }"#

        // When
        let sut = try resolved(clips: [carrier])

        // Then
        let clip = try #require(sut.clips.first { $0.id == "carrier" })
        guard case let .null(null) = clip.content, case let .box(width, height) = null.geometry else {
            Issue.record("the clip is a null placed by its box")
            return
        }
        #expect(width.map(\.value) == [200])
        #expect(height.map(\.value) == [100])
        #expect(clip.box?.size == Size(width: 200, height: 100))
        #expect(clip.box?.position.values.map(\.fixed) == [Point(x: 600, y: 400)])
    }

    @Test("a null given by an area resolves to a null entry placed by its area, and reads back equal")
    func resolvesAreaForm() throws {
        // Given
        let carrier = #"{ "id": "carrier", "null": true, "at": [0, 4], "area": [100, 200, 400, 300] }"#

        // When
        let sut = try resolved(clips: [carrier])

        // Then
        let clip = try #require(sut.clips.first { $0.id == "carrier" })
        guard case let .null(null) = clip.content, case .area = null.geometry else {
            Issue.record("the clip is a null placed by its area")
            return
        }
        #expect(clip.box == nil)
    }

    @Test(
        "a null without a box, with both forms, or named by a track matte stops, naming a null",
        arguments: [
            (
                #"{ "id": "carrier", "null": true, "at": [0, 4] }"#,
                #"clips[0]#carrier (null): a null needs "area", or "width" and "height""#
            ),
            (
                #"{ "id": "carrier", "null": true, "at": [0, 4], "area": [0, 0, 10, 10], "width": 10, "height": 10 }"#,
                #"clips[0]#carrier (null): a null is given by "area" or by "width" and "height", and this one writes both"#
            ),
            (
                ##"""
                { "id": "carrier", "null": true, "at": [0, 4], "width": 10, "height": 10 },
                { "media": "/abs/card.png", "at": [0, 4], "trackMatte": { "clip": "carrier", "mode": "alpha" } }
                """##,
                #"clips[1].trackMatte.clip (image): "carrier" is a null, which draws nothing, and a track matte is a connected or sequence media clip, title or shape"#
            )
        ]
    )
    func refusesNull(
        clips: String,
        message: String
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1920, 1080] }, "storyline": [ { "solid": "#202020", "duration": 4 } ],
              "clips": [ \#(clips) ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try Fixture.documentPlanner.plan(Fixture.json(document)) }
        #expect(error?.description == message)
    }

    @Test(
        "a null entry that holds a key of how a picture composites is refused by the reader",
        arguments: [
            ("opacity", #"[ { "at": 0, "value": 1, "ease": "linear" } ]"#),
            ("lane", "1")
        ]
    )
    func refusesPictureKey(
        key: String,
        value: String
    ) throws {
        // Given
        let carrier = #"{ "id": "carrier", "null": true, "at": [0, 4], "width": 200, "height": 100 }"#
        let text = try replacing(key, ofClip: 0, with: value, in: writer.write(resolved(clips: [carrier])))

        // When
        let error = #expect(throws: ModelError.self) { try reader.read(text) }

        // Then
        #expect(error?.description.hasPrefix(#"clips[0] (clip): unknown key "\#(key)""#) == true)
    }

    @Test(
        "a null draws no item, and its child draws what it draws parented to a rect placed the same way",
        arguments: [
            #""width": 200, "height": 100, "position": [600, 400], "rotation": 30, "scale": 1.5"#,
            #""area": [100, 200, 400, 300], "rotation": -20, "scale": [2, 0.5]"#,
            #"""
            "width": 200, "height": 100, "anchor": "top-left",
            "keyframes": [ { "at": 0, "position": [100, 100], "rotation": 0, "scale": 1 }, { "at": 2, "position": [900, 500], "rotation": 90, "scale": 2 } ]
            """#
        ]
    )
    func carriesChild(placement: String) throws {
        // Given
        let null = try resolved(clips: [#"{ "id": "carrier", "null": true, "at": [0, 4], \#(placement) }"#, child])
        let rect = try resolved(clips: [#"{ "id": "carrier", \#(Self.rect), "at": [0, 4], \#(placement) }"#, child])

        // When
        let nullItems = [0.5, 1, 1.5].map { evaluator.displayList(of: null, at: $0).items }
        let rectItems = [0.5, 1, 1.5].map { evaluator.displayList(of: rect, at: $0).items }

        // Then
        #expect(nullItems.allSatisfy { items in !items.contains { $0.origin?.id == "carrier" } })
        #expect(rectItems.allSatisfy { items in items.contains { $0.origin?.id == "carrier" } })
        #expect(nullItems.map { $0.filter { $0.origin?.id == "child" } } == rectItems.map { $0.filter { $0.origin?.id == "child" } })
        #expect(nullItems.allSatisfy { $0.contains { $0.origin?.id == "child" } })
    }

    @Test("a tracked null carries its child as a tracked rect placed the same way does, and draws no item")
    func carriesChildOnTrack() throws {
        // Given
        let track = #"""
            "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3],
            "track": { "time": 1.12, "frames": [
              { "time": 1.01, "quad": [[100, 100], [300, 100], [300, 140], [100, 140]] },
              { "time": 1.13, "quad": [[102, 100], [302, 100], [302, 140], [102, 140]] },
              { "time": 1.2, "quad": [[104, 101], [304, 101], [304, 141], [104, 141]] } ] }
            """#
        let child = ##"{ "id": "child", "shape": "rect", "fill": "#00FF00", "at": [1, 3], "parent": "carrier", "area": [10, 10, 20, 20] }"##
        let null = try resolved(connected: [#"{ "id": "carrier", "null": true, \#(track) }"#, child])
        let rect = try resolved(connected: [#"{ "id": "carrier", \#(Self.rect), \#(track) }"#, child])

        // When
        let nullItems = [0.05, 0.15, 0.25].map { evaluator.displayList(of: null, at: $0).items }
        let rectItems = [0.05, 0.15, 0.25].map { evaluator.displayList(of: rect, at: $0).items }

        // Then
        #expect(nullItems.allSatisfy { items in !items.contains { $0.origin?.id == "carrier" } })
        #expect(nullItems.map { $0.filter { $0.origin?.id == "child" } } == rectItems.map { $0.filter { $0.origin?.id == "child" } })
        #expect(nullItems[0].first { $0.origin?.id == "child" }?.transform != nullItems[2].first { $0.origin?.id == "child" }?.transform)
    }

    @Test("a clip area and a point of a clip area that name a null take its box as they take a rect's placed the same way")
    func namesNullInClipArea() throws {
        // Given
        let placement = #""at": [0, 4], "width": 200, "height": 100, "position": [600, 400], "rotation": 30"#
        let bar = ##"{ "id": "bar", "shape": "rect", "fill": "#000000", "at": [0, 4], "area": { "clip": "carrier", "padding": 24 } }"##
        let note = ##"""
            { "id": "note", "shape": "rect", "fill": "#0000FF", "at": [0, 4], "width": 40, "height": 20, "anchor": "left",
              "position": { "area": { "clip": "carrier" }, "point": "right" } }
            """##
        let null = try resolved(clips: [#"{ "id": "carrier", "null": true, \#(placement) }"#, bar, note])
        let rect = try resolved(clips: [#"{ "id": "carrier", \#(Self.rect), \#(placement) }"#, bar, note])

        // When
        let nullItems = evaluator.displayList(of: null, at: 1).items.filter { ["bar", "note"].contains($0.origin?.id) }
        let rectItems = evaluator.displayList(of: rect, at: 1).items.filter { ["bar", "note"].contains($0.origin?.id) }

        // Then
        #expect(nullItems.map(\.origin?.id) == ["bar", "note"])
        #expect(nullItems == rectItems)
    }

    @Test("timeline gives a null its kind null and no lane, from the document and from its resolved document")
    func reportsNullKind() throws {
        // Given
        let document = try Fixture.json(document(clips: [#"{ "id": "carrier", "null": true, "at": [0, 4], "width": 10, "height": 10 }"#, child]))
        let sut = TimelineReporter(planner: Fixture.documentPlanner)

        // When
        let planned = try sut.report(of: document).machineOutput
        let read = sut.report(of: try resolved(clips: [#"{ "id": "carrier", "null": true, "at": [0, 4], "width": 10, "height": 10 }"#, child])).machineOutput

        // Then
        for output in [planned, read] {
            let entry = try #require(output.objectValue?["clips"]?.arrayValue?.first?.objectValue)
            #expect(entry["kind"] == .string("null"))
            #expect(entry["lane"] == .null)
            #expect(entry["ownSpace"]?.objectValue?["kind"] == .string("box"))
        }
    }

    // MARK: - Private
    private func document(clips: [String]) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "storyline": [ { "id": "back", "solid": "#202020", "duration": 4 } ], "clips": [ \#(clips.joined(separator: ", ")) ] }
            """#
    }

    private func resolved(clips: [String]) throws -> ResolvedSequence {
        try resolved(document(clips: clips))
    }

    // Connected clips on a storyline clip of `/abs/screen.mp4` that plays media [1, 3) over the edit range [0, 2).
    private func resolved(connected: [String]) throws -> ResolvedSequence {
        try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 1, "out": 3, "connected": [ \#(connected.joined(separator: ", ")) ] } ] }
            """#)
    }

    // The document resolved, written and read back, which must give the same sequence.
    private func resolved(_ document: String) throws -> ResolvedSequence {
        let sequence = try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
        let read = try reader.read(writer.write(sequence))
        #expect(read == sequence)

        return read
    }

    private func replacing(
        _ key: String,
        ofClip index: Int,
        with value: String,
        in text: String
    ) throws -> String {
        let root = try #require(try JSONReader().read(text).objectValue)
        var clips = try #require(root["clips"]?.arrayValue)
        let clip = try #require(clips[index].objectValue)
        clips[index] = .object(clip.setting(key, to: try Fixture.json(value)))

        return JSONWriter().write(.object(root.setting("clips", to: .array(clips))))
    }
}
