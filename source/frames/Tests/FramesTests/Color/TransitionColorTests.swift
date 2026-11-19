//
//  TransitionColorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/20/26.
//

import Testing

@testable import Frames

// A transition's cover and matte name their file's colour space as a media clip does: the preset reads it, resolve
// writes it after the media keys, the display list carries it on the cover's source and the matte, and every place
// that names a file reads it in one colour space.
@Suite("Transition Color Tests")
struct TransitionColorTests {
    // MARK: - Property
    private let presetReader = PresetReader()
    private let writer = ResolvedDocumentWriter()
    private let reader = ResolvedDocumentReader()
    private let listWriter = DisplayListWriter()
    private let listReader = DisplayListReader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a media cover and a matte read the colour space they name, nil where they name none")
    func readsPresetColorSpace() throws {
        // Given
        let named = try Fixture.json(#"""
            { "description": "", "seconds": 1, "cover": { "media": "/abs/leak.mov", "colorSpace": "rec709" },
              "matte": { "media": "/abs/matte.png", "colorSpace": "display-p3" } }
            """#)
        let unnamed = try Fixture.json(#"""
            { "description": "", "seconds": 1, "cover": { "media": "/abs/leak.mov" }, "matte": { "media": "/abs/matte.png" } }
            """#)

        // When
        let preset = try presetReader.transition(from: named)
        let plain = try presetReader.transition(from: unnamed)

        // Then
        #expect(preset.cover?.colorSpace == .rec709)
        #expect(preset.matte?.colorSpace == .displayP3)
        #expect(plain.cover?.colorSpace == nil)
        #expect(plain.matte?.colorSpace == nil)
    }

    @Test(
        "a colour cover's colour space and a name outside the table stop",
        arguments: [
            (##"{ "description": "", "seconds": 1, "cover": { "color": "#000000", "colorSpace": "rec709" } }"##, #"cover (cover): takes only one of "color", "colorSpace""#),
            (#"{ "description": "", "seconds": 1, "matte": { "media": "/abs/matte.png", "colorSpace": "p3" } }"#, #"matte.colorSpace (matte): unknown value "p3". Allowed: srgb, display-p3, rec2020, rec709, rec2100-pq, rec2100-hlg"#)
        ]
    )
    func refusesPresetColorSpace(
        text: String,
        message: String
    ) throws {
        // Given
        let value = try Fixture.json(text)

        // When, Then
        let error = #expect(throws: (any Error).self) { try presetReader.transition(from: value) }
        #expect(error.map { "\($0)" } == message)
    }

    @Test("a cover and a matte write their colour space after their media keys, null where they name none, and read back")
    func writesResolvedColorSpace() throws {
        // Given
        let resolved = try resolved(cover: "rec709", matte: nil)

        // When
        let written = try #require(try JSONReader().read(writer.write(resolved)).objectValue)

        // Then
        let transition = try #require(
            written["storyline"]?.arrayValue?.last?.objectValue?["transition"]?.objectValue
        )
        let cover = try #require(transition["cover"]?.objectValue)
        let matte = try #require(transition["matte"]?.objectValue)
        #expect(cover.keys == ["file", "sha256", "frames", "colorSpace", "duration", "ease", "revealFrom", "keys"])
        #expect(cover["colorSpace"] == .string("rec709"))
        #expect(matte.keys == ["file", "sha256", "colorSpace", "duration", "softness", "invert", "ease"])
        #expect(matte["colorSpace"] == .null)
        #expect(try reader.read(writer.write(resolved)) == resolved)
    }

    @Test("the cover's source and the matte carry their colour space in the display list, and read back")
    func carriesListColorSpace() throws {
        // Given
        let resolved = try resolved(cover: "rec709", matte: "display-p3")

        // When
        let list = Evaluator().displayList(of: resolved, at: 3)

        // Then
        let pictures = list.items.compactMap { item -> PictureItem? in
            guard case let .picture(picture) = item.content else { return nil }

            return picture
        }
        guard case let .media(cover)? = pictures.last?.source else {
            Issue.record("the cover shows no media")
            return
        }
        #expect(cover.reading.colorSpace == .rec709)
        let matte = try #require(pictures.compactMap(\.matte).first)
        #expect(matte.frame.reading == .analysis(colorSpace: .displayP3))

        let written = try #require(try JSONReader().read(listWriter.write(list)).objectValue)
        let items = written["items"]?.arrayValue?.compactMap(\.objectValue) ?? []
        let mattes = items.compactMap { $0["matte"]?.objectValue }
        let writtenMatte = try #require(mattes.first)
        #expect(writtenMatte.keys == ["source", "frame", "colorSpace", "progress", "softness", "invert"])
        #expect(writtenMatte["colorSpace"] == .string("display-p3"))
        // A list with no grain reads back with seed 0, so it is compared by the bytes it writes.
        #expect(try listWriter.write(listReader.read(listWriter.write(list))) == listWriter.write(list))
    }

    @Test(
        "a cover or matte that reads a clip's file in another colour space stops, one naming none read by its tags",
        arguments: [
            ("/abs/run.mp4", "/abs/matte.png", #"storyline[1].transition.cover (cover): "/abs/run.mp4" is read as its tags say here and as "rec709" at storyline[0], and every place that names a file reads it in one colour space"#),
            ("/abs/leak.mov", "/abs/run.mp4", #"storyline[1].transition.matte (matte): "/abs/run.mp4" is read as its tags say here and as "rec709" at storyline[0], and every place that names a file reads it in one colour space"#)
        ]
    )
    func refusesFileInTwoColorSpaces(
        cover: String,
        matte: String,
        message: String
    ) throws {
        // Given
        let plan = try plan(
            storyline: #"{ "media": "/abs/run.mp4", "colorSpace": "rec709", "in": 0, "out": 3 }"#,
            presets: presets(cover: (cover, nil), matte: (matte, nil))
        )

        // When, Then
        let error = #expect(throws: ResolveError.self) { try checkMediaColorSpaces(of: plan) }
        #expect(error?.description == message)
    }

    @Test("a cover and a matte that read a clip's file in its colour space pass")
    func acceptsFileInOneColorSpace() throws {
        // Given
        let plan = try plan(
            storyline: #"{ "media": "/abs/run.mp4", "colorSpace": "rec709", "in": 0, "out": 3 }"#,
            presets: presets(cover: ("/abs/run.mp4", .rec709), matte: ("/abs/run.mp4", .rec709))
        )

        // When, Then
        #expect(throws: Never.self) { try checkMediaColorSpaces(of: plan) }
    }

    // MARK: - Private
    private func presets(
        cover: (media: String, colorSpace: ColorSpace?),
        matte: (media: String, colorSpace: ColorSpace?)
    ) -> PresetTable {
        PresetTable(
            transitions: [
                "reveal": TransitionPreset(
                    description: "",
                    seconds: 1,
                    over: .incoming,
                    audio: .constantPower,
                    incoming: Span(ease: .linear, keys: []),
                    outgoing: nil,
                    cover: Cover(
                        source: .media(cover.media),
                        colorSpace: cover.colorSpace,
                        span: Span(ease: .linear, keys: [])
                    ),
                    matte: Matte(
                        media: matte.media,
                        colorSpace: matte.colorSpace,
                        softness: 0.1,
                        isInverted: false,
                        ease: .linear
                    )
                )
            ],
            animations: Fixture.presets.animations,
            filters: [:]
        )
    }

    // `/abs/run.mp4` and `/abs/short.mp4` with the transition between them, its cover `/abs/leak.mov` and its matte
    // `/abs/matte.png` in the colour spaces given.
    private func resolved(
        cover: String?,
        matte: String?
    ) throws -> ResolvedSequence {
        try resolved(
            storyline: #"{ "media": "/abs/run.mp4", "in": 0, "out": 3 }"#,
            presets: presets(
                cover: ("/abs/leak.mov", cover.flatMap(ColorSpace.init(rawValue:))),
                matte: ("/abs/matte.png", matte.flatMap(ColorSpace.init(rawValue:)))
            )
        )
    }

    private func resolved(
        storyline first: String,
        presets: PresetTable
    ) throws -> ResolvedSequence {
        try ResolvedSequence(plan: plan(storyline: first, presets: presets), hashes: FileHashTable())
    }

    private func checkMediaColorSpaces(of plan: SequencePlan) throws {
        try ResolvedSequence(plan: plan, hashes: FileHashTable())
            .checkMediaColorSpaces(taggedColorSpaces: plan.time.taggedColorSpaces)
    }

    // A sequence of `first` and `/abs/short.mp4` with the transition between them.
    private func plan(
        storyline first: String,
        presets: PresetTable
    ) throws -> SequencePlan {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: presets,
            ocr: Fixture.ocr,
            languages: nil,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            library: Fixture.library
        )
        let document = #"""
            { "kind": "sequence", "storyline": [ \#(first),
                { "media": "/abs/short.mp4", "in": 0, "out": 3, "transition": "reveal" } ] }
            """#
        return try planner.plan(Fixture.json(document))
    }
}
