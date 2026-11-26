//
//  MediaPlayTests.swift
//  FramesTests
//
//  Created by JSilver on 11/26/26.
//

import Testing

@testable import Frames

// Each showing of a file by a time map of its own is a play of its own, named by its place in the document, a nested
// sequence's places continued from the clip that holds it, so every use of a compound clip or a template, and a clip
// and the clip that is its track matte, read their frames in plays apart (FRAMES-21 Rules). Each document is resolved
// and evaluated.
@Suite("Media Play Tests")
struct MediaPlayTests {
    // MARK: - Property
    private let sut = Evaluator()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a compound clip used twice at once shows its media in a play for each use")
    func playsCompoundClipTwice() throws {
        // Given
        let compound = #"""
            { "kind": "media", "media": { "kind": "sequence", "format": { "size": [1080, 1920] },
                "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 2 } ] }, "at": [0, 2] }
            """#
        let sequence = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 } ],
              "clips": [ \#(compound), \#(compound) ] }
            """#)

        // When
        let frames = mediaFrames(in: sut.displayList(of: sequence, at: 1)).filter { $0.file.path == "/abs/run.mp4" }

        // Then
        #expect(frames.count == 2)
        #expect(frames.allSatisfy { $0.picture == frames.first?.picture })
        #expect(Set(frames.map(\.play)) == [
            .place("clips[0].media.storyline[0]"),
            .place("clips[1].media.storyline[0]")
        ])
    }

    @Test("a template used twice at once shows its media in a play for each use")
    func playsTemplateTwice() throws {
        // Given
        let directory = try PackDirectory()
        try directory.addPack("shorts")
        try directory.write(
            #"{ "kind": "sequence", "params": { "clip": { "type": "video", "description": "the clip" } }, "storyline": [ { "kind": "media", "media": { "param": "clip" } } ] }"#,
            in: "shorts",
            at: "templates/leak.json"
        )
        let leak = directory.installed.appendingPathComponent("shorts/media/leak.mov").path
        let mediaFacts = MediaFactTable(files: [
            leak: ProbedMedia(kind: .video, duration: 2, fps: 24, size: Size(width: 1080, height: 1920))
        ])
        let planner = DocumentPlanner(
            mediaFacts: mediaFacts,
            presets: Fixture.presets,
            shaper: Fixture.shaper,
            library: directory.library(mediaFacts: mediaFacts)
        )
        let instance = #"""
            { "kind": "media", "media": { "kind": "template", "template": "shorts/leak", "args": { "clip": "shorts/leak.mov" } }, "at": [0, 2] }
            """#
        let sequence = try ResolvedSequence(
            plan: planner.plan(Fixture.json(#"""
                { "kind": "sequence", "format": { "size": [1080, 1920] },
                  "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 } ],
                  "clips": [ \#(instance), \#(instance) ] }
                """#)),
            hashes: FileHashTable()
        )

        // When
        let frames = mediaFrames(in: sut.displayList(of: sequence, at: 1)).filter { $0.file.path == leak }

        // Then
        #expect(frames.count == 2)
        #expect(Set(frames.map(\.play)) == [
            .place("clips[0].media.storyline[0]"),
            .place("clips[1].media.storyline[0]")
        ])
    }

    @Test("a clip and the clip of the same file that is its track matte read their frames in two plays")
    func playsTrackMatteApart() throws {
        // Given
        let sequence = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 4 } ],
              "clips": [
                { "id": "m", "kind": "media", "media": "/abs/run.mp4", "in": 0, "at": [0, 4] },
                { "kind": "media", "media": "/abs/run.mp4", "in": 0, "at": [0, 4], "trackMatte": { "clip": "m", "mode": "luma" } } ] }
            """#)

        // When
        let frames = mediaFrames(in: sut.displayList(of: sequence, at: 1)).filter { $0.file.path == "/abs/run.mp4" }

        // Then
        #expect(frames.count == 2)
        #expect(frames.allSatisfy { $0.picture == frames.first?.picture })
        #expect(Set(frames.map(\.play)) == [.place("clips[0]#m"), .place("clips[1]")])
    }

    // MARK: - Private
    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    // The media frames a list shows, those of its pictures, its transition mattes and its track mattes' lists, in each
    // of its sample lists and every list nested in it.
    private func mediaFrames(in list: DisplayList) -> [MediaFrame] {
        switch list.content {
        case let .items(items):
            items.flatMap(mediaFrames(in:))

        case let .samples(samples):
            samples.flatMap { $0.flatMap(mediaFrames(in:)) }
        }
    }

    private func mediaFrames(in item: DisplayItem) -> [MediaFrame] {
        let matted = item.trackMatte.map { mediaFrames(in: $0.source) } ?? []
        guard case let .picture(picture) = item.content else { return matted }

        let shown: [MediaFrame] = switch picture.source {
        case let .media(frame):
            [frame]

        case let .displayList(nested):
            mediaFrames(in: nested)
        }

        return matted + shown + (picture.matte.map { [$0.frame] } ?? [])
    }
}
