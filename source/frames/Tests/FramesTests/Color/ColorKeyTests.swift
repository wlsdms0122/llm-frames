//
//  ColorKeyTests.swift
//  FramesTests
//
//  Created by JSilver on 11/20/26.
//

import Testing

@testable import Frames

// The colour keys of a document: `format.colorSpace` and `format.compositing`, a media clip's `colorSpace` and
// `toneMap`, and a `lut`'s `space`, as check takes them, resolve plans and writes them and the reader reads them back.
@Suite("Color Key Tests")
struct ColorKeyTests {
    // MARK: - Property
    private let checker = KeyChecker(mediaKinds: Fixture.mediaKinds)
    private let writer = ResolvedDocumentWriter()
    private let reader = ResolvedDocumentReader()
    private let hashes = FileHashTable()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a format without colour keys is srgb and composites on the encoded form, both written out")
    func defaultsFormatColor() throws {
        // When
        let resolved = try resolved(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ] }"#)

        // Then
        #expect(resolved.format.colorSpace == .srgb)
        #expect(resolved.format.compositing == .encoded)
        let format = try #require(try written(resolved)["format"]?.objectValue)
        #expect(format["colorSpace"] == .string("srgb"))
        #expect(format["compositing"] == .string("encoded"))
    }

    @Test(
        "a written colour space and compositing are kept and read back",
        arguments: [(ColorSpace.rec2100PQ, Compositing.linear), (.displayP3, .encoded), (.rec709, .linear)]
    )
    func keepsFormatColor(
        colorSpace: ColorSpace,
        compositing: Compositing
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "colorSpace": "\#(colorSpace.rawValue)", "compositing": "\#(compositing.rawValue)" },
              "storyline": [ { "media": "/abs/run.mp4" } ] }
            """#

        // When
        let resolved = try resolved(document)
        let read = try reader.read(writer.write(resolved))

        // Then
        #expect(resolved.format.colorSpace == colorSpace)
        #expect(resolved.format.compositing == compositing)
        #expect(read == resolved)
    }

    @Test(
        "a colour space or compositing outside the table stops at check",
        arguments: [
            (#""colorSpace": "p3""#, #"format.colorSpace (format): unknown value "p3". Allowed: srgb, display-p3, rec2020, rec709, rec2100-pq, rec2100-hlg"#),
            (#""compositing": "gamma""#, #"format.compositing (format): unknown value "gamma". Allowed: encoded, linear"#)
        ]
    )
    func refusesFormatColor(
        member: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "format": { \#(member) }, "storyline": [ { "media": "/abs/run.mp4" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a storyline clip and a media clip read their file by its tags and tone map it unless they write otherwise")
    func defaultsMediaColor() throws {
        // When
        let resolved = try resolved(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "connected": [ { "media": "/abs/card.png", "at": [0, 1] } ] } ] }
            """#)

        // Then
        let entry = try #require(resolved.storyline.first)
        #expect(entry.colorSpace == nil)
        #expect(entry.isToneMapped == true)
        let clip = try #require(mediaClip(resolved.clips.first))
        #expect(clip.colorSpace == nil)
        #expect(clip.isToneMapped == true)
    }

    @Test("a written colorSpace and toneMap are kept on storyline clips and media clips, written after solid and conform")
    func keepsMediaColor() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [
                { "media": "/abs/run.mp4", "colorSpace": "rec709", "toneMap": false, "connected": [
                  { "media": "/abs/short.mp4", "colorSpace": "rec2100-hlg", "at": [0, 1] },
                  { "media": "/abs/card.png", "colorSpace": "display-p3", "toneMap": false, "at": [0, 1] } ] } ] }
            """#

        // When
        let resolved = try resolved(document)
        let written = try written(resolved)

        // Then
        let entry = try #require(resolved.storyline.first)
        #expect(entry.colorSpace == .rec709)
        #expect(entry.isToneMapped == false)
        #expect(resolved.clips.compactMap(mediaClip).map(\.colorSpace) == [.rec2100HLG, .displayP3])
        #expect(resolved.clips.compactMap(mediaClip).map(\.isToneMapped) == [true, false])

        let storyline = try #require(written["storyline"]?.arrayValue?.first?.objectValue)
        #expect(Array(storyline.keys.prefix(6)) == ["place", "id", "media", "solid", "colorSpace", "toneMap"])
        #expect(storyline["colorSpace"] == .string("rec709"))
        #expect(storyline["toneMap"] == .bool(false))
        let clip = try #require(written["clips"]?.arrayValue?.last?.objectValue)
        let conform = try #require(clip.keys.firstIndex(of: "conform"))
        #expect(Array(clip.keys[conform...].prefix(3)) == ["conform", "colorSpace", "toneMap"])
        #expect(clip["colorSpace"] == .string("display-p3"))
        #expect(clip["toneMap"] == .bool(false))

        #expect(try reader.read(writer.write(resolved)) == resolved)
    }

    @Test("a compound clip and a solid write colorSpace and toneMap as null")
    func writesNullForNestedAndSolid() throws {
        // Given
        let document = ##"""
            { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [
                { "solid": "#000000", "duration": 1 },
                { "media": { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "colorSpace": "rec709" } ] } } ] }
            """##

        // When
        let resolved = try resolved(document)
        let storyline = try #require(try written(resolved)["storyline"]?.arrayValue)

        // Then
        for entry in storyline {
            #expect(entry.objectValue?["colorSpace"] == .null)
            #expect(entry.objectValue?["toneMap"] == .null)
        }
        guard case let .nested(nested) = resolved.storyline.last?.media else {
            Issue.record("the compound clip is not nested")
            return
        }
        #expect(nested.storyline.first?.colorSpace == .rec709)
        #expect(nested.storyline.first?.isToneMapped == true)
        #expect(try reader.read(writer.write(resolved)) == resolved)
    }

    @Test(
        "colorSpace and toneMap stop on a compound clip, a template instance, an audio clip and a solid",
        arguments: [
            (
                #"{ "media": { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ] }, "toneMap": false }"#,
                #"storyline[0] (compound): unknown key "toneMap""#
            ),
            (
                #"{ "media": "/abs/run.mp4", "connected": [ { "media": { "template": "pack/intro" }, "at": [0, 1], "colorSpace": "rec709" } ] }"#,
                #"storyline[0].connected[0] (compound): unknown key "colorSpace""#
            ),
            (
                #"{ "media": "/abs/run.mp4", "connected": [ { "media": "/abs/bgm.m4a", "at": 0, "colorSpace": "rec709" } ] }"#,
                #"storyline[0].connected[0] (audio): unknown key "colorSpace""#
            ),
            (##"{ "solid": "#000000", "duration": 1, "toneMap": true }"##, #"storyline[0] (solid): unknown key "toneMap""#)
        ]
    )
    func refusesMediaColorOffFiles(
        clip: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ \#(clip) ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true)
    }

    @Test(
        "a resolved entry with a colour space or tone mapping where it shows no file, or no tone mapping where it does, stops",
        arguments: [
            (0, "colorSpace", #""rec709""#, #"storyline[0].colorSpace (storyline clip): only media of a file is read in a colour space and tone mapped, so it is null here, found "rec709""#),
            (0, "toneMap", "true", "storyline[0].toneMap (storyline clip): only media of a file is read in a colour space and tone mapped, so it is null here, found true"),
            (1, "toneMap", "null", "storyline[1].toneMap (storyline clip): expected true or false, found null")
        ]
    )
    func refusesUnreadableMediaColor(
        index: Int,
        key: String,
        value: String,
        message: String
    ) throws {
        // Given
        let resolved = try resolved(##"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 1 }, { "media": "/abs/run.mp4" } ] }
            """##)
        let root = try #require(try JSONReader().read(writer.write(resolved)).objectValue)
        var storyline = try #require(root["storyline"]?.arrayValue)
        let entry = try #require(storyline[index].objectValue)
        storyline[index] = .object(entry.setting(key, to: try JSONReader().read(value)))

        // When, Then
        let error = #expect(throws: ModelError.self) { try reader.read(.object(root.setting("storyline", to: .array(storyline)))) }
        #expect(error?.description == message)
    }

    @Test("a LUT is built for srgb unless it names its space, which is kept through resolve and the display list")
    func keepsLUTSpace() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [
                { "media": "/abs/run.mp4", "filter": { "op": "lut", "file": "/abs/look.cube", "amount": 1 } },
                { "media": "/abs/run.mp4", "filter": { "op": "lut", "file": "/abs/look.cube", "amount": 1, "space": "rec2100-pq" } } ] }
            """#

        // When
        let resolved = try resolved(document)
        let spaces = resolved.storyline.map { entry in
            FilterEntry.entries(of: entry.filter, at: 0).flatMap(\.operations).compactMap { operation -> ColorSpace? in
                guard case let .lut(_, _, space) = operation else { return nil }
                return space
            }
        }

        // Then
        #expect(spaces == [[.srgb], [.rec2100PQ]])
        #expect(try reader.read(writer.write(resolved)) == resolved)
    }

    @Test("a LUT space outside the table stops at check")
    func refusesLUTSpace() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "filter": { "op": "lut", "file": "/abs/look.cube", "amount": 1, "space": "slog3" } } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        #expect(error?.description.hasPrefix(#"storyline[0].filter.space (lut): unknown value "slog3""#) == true)
    }

    @Test("a preset's LUT reads its space, srgb where it names none")
    func readsPresetLUTSpace() throws {
        // Given
        let text = #"""
            { "description": "x", "ops": [ { "op": "lut", "file": "/abs/a.cube", "amount": 1 },
                                           { "op": "lut", "file": "/abs/b.cube", "amount": 0.5, "space": "rec709" } ] }
            """#

        // When
        let preset = try PresetReader().filter(from: Fixture.json(text))

        // Then
        #expect(preset.operations == [
            .lut(file: "/abs/a.cube", amount: 1, space: .srgb),
            .lut(file: "/abs/b.cube", amount: 0.5, space: .rec709)
        ])
    }

    @Test(
        "two clips that read the same file in different colour spaces stop, naming both places",
        arguments: [
            (#""colorSpace": "rec709""#, "", #"storyline[0].connected[0] (clip): "/abs/run.mp4" is read as its tags say here and as "rec709" at storyline[0], and every place that names a file reads it in one colour space"#),
            (#""colorSpace": "rec709""#, #""colorSpace": "rec2020""#, #"storyline[0].connected[0] (clip): "/abs/run.mp4" is read as "rec2020" here and as "rec709" at storyline[0], and every place that names a file reads it in one colour space"#)
        ]
    )
    func refusesFileInTwoColorSpaces(
        storyline: String,
        connected: String,
        message: String
    ) throws {
        // Given
        let comma = connected.isEmpty ? "" : ","
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", \#(storyline), "connected": [
                { "media": "/abs/run.mp4", "at": [0, 1]\#(comma) \#(connected) } ] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try checkMediaColorSpaces(of: document) }
        #expect(error?.description == message)
    }

    @Test("clips that read a file in one colour space, inside a compound clip too, pass")
    func acceptsFileInOneColorSpace() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [
                { "media": "/abs/run.mp4", "colorSpace": "rec709", "connected": [
                  { "media": "/abs/run.mp4", "colorSpace": "rec709", "at": [0, 1], "toneMap": false } ] },
                { "media": { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "colorSpace": "rec709" } ] } } ] }
            """#

        // When, Then
        #expect(throws: Never.self) { try checkMediaColorSpaces(of: document) }
    }

    @Test("a clip that writes the space a file's tags name and one that writes nothing read it in one colour space")
    func acceptsTaggedSpaceWrittenOrNot() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/card.png", "duration": 1, "colorSpace": "srgb", "connected": [
                { "media": "/abs/card.png", "at": [0, 1] } ] } ] }
            """#

        // When, Then
        #expect(throws: Never.self) { try checkMediaColorSpaces(of: document) }
    }

    @Test("a clip that writes nothing for a tagged file is named with the space its tags name when another differs")
    func refusesOtherSpaceThanTagged() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/card.png", "duration": 1, "colorSpace": "rec709", "connected": [
                { "media": "/abs/card.png", "at": [0, 1] } ] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try checkMediaColorSpaces(of: document) }
        #expect(error?.description == #"storyline[0].connected[0] (clip): "/abs/card.png" is read as "srgb" here and as "rec709" at storyline[0], and every place that names a file reads it in one colour space"#)
    }

    // MARK: - Private
    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: hashes)
    }

    private func checkMediaColorSpaces(of document: String) throws {
        let plan = try Fixture.documentPlanner.plan(Fixture.json(document))
        try ResolvedSequence(plan: plan, hashes: hashes)
            .checkMediaColorSpaces(taggedColorSpaces: plan.time.taggedColorSpaces)
    }

    private func written(_ resolved: ResolvedSequence) throws -> JSONObject {
        try #require(try JSONReader().read(writer.write(resolved)).objectValue)
    }

    private func mediaClip(_ clip: ResolvedClip?) -> ResolvedMediaClip? {
        guard case let .media(media) = clip?.content else { return nil }

        return media
    }
}
