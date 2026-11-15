//
//  TimelineReporterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("TimelineReporter Tests")
struct TimelineReporterTests {
    // MARK: - Property
    private let sut = TimelineReporter(planner: Fixture.documentPlanner)
    private let document = ##"""
        { "kind": "sequence",
          "storyline": [
            { "id": "intro", "media": "/abs/short.mp4", "in": 1, "out": 3,
              "connected": [ { "shape": "box", "area": "Send", "animation": "pulse" } ] },
            { "solid": "#000000", "duration": 2, "transition": { "preset": "flash", "seconds": 1 } }
          ],
          "clips": [
            { "at": [0, 4], "title": "Top", "style": "headline", "lane": 2, "animation": "pop" },
            { "at": 1, "media": "/abs/ding.wav" }
          ] }
        """##

    // MARK: - Initializer
    // MARK: - Test
    @Test("the machine output is the timeline object FRAMES-23 gives, with places, ranges, transitions and parents")
    func writesMachineOutput() throws {
        // Given
        let value = try Fixture.json(document)

        // When
        let report = try sut.report(of: value)

        // Then
        let expected = #"""
            {"timeline": "1.0.0", "duration": 4, "storyline": [\#
            {"place": "storyline[0]#intro", "id": "intro", "media": "/abs/short.mp4", "edit": [0, 2], "drawn": [0, 2.5], "clip": [1, 3], "speed": 1, "transition": null}, \#
            {"place": "storyline[1]", "id": null, "media": null, "edit": [2, 4], "drawn": [1.5, 4], "clip": [0, 2], "speed": 1, "transition": {"preset": "flash", "seconds": 1}}], \#
            "clips": [\#
            {"place": "storyline[0]#intro.connected[0]", "id": null, "kind": "box", "visible": [0, 2.5], "lane": 1, "parent": "storyline[0]#intro", "animation": {"entrance": null, "loop": {"preset": "pulse", "period": 1}, "exit": null}}, \#
            {"place": "clips[0]", "id": null, "kind": "title", "visible": [0, 4], "lane": 2, "parent": null, "animation": {"entrance": {"preset": "pop", "seconds": 0.25}, "loop": null, "exit": null}}, \#
            {"place": "clips[1]", "id": null, "kind": "audio", "visible": [1, 2.5], "lane": null, "parent": null, "animation": null}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("times and lengths are written to the nearest microsecond, in their shortest form")
    func roundsTimes() throws {
        // Given
        let value = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 0.1 }, { "solid": "#FFFFFF", "duration": 0.2 } ] }
            """##)

        // When
        let report = try sut.report(of: value)

        // Then
        let output = report.machineOutput.objectValue
        #expect(report.duration != 0.3)
        #expect(output?["duration"] == .number(0.3))
        #expect(output?["storyline"]?.arrayValue?[1].objectValue?["edit"] == .array([.number(0.1), .number(0.3)]))
    }

    @Test("an entry whose media is a compound clip has nested, the timeline object of the document inside")
    func nestsCompoundTimeline() throws {
        // Given
        let value = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "media": { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 2 } ],
                           "clips": [ { "title": "a", "style": "headline" } ] } }
            ] }
            """##)

        // When
        let report = try sut.report(of: value)

        // Then
        let entry = try #require(report.machineOutput.objectValue?["storyline"]?.arrayValue?.first?.objectValue)
        let nested = try #require(entry["nested"]?.objectValue)
        #expect(entry["media"] == .null)
        #expect(entry["clip"] == .array([.number(0), .number(2)]))
        #expect(nested["timeline"] == .string("1.0.0"))
        #expect(nested["clips"]?.arrayValue?.first?.objectValue?["place"] == .string("storyline[0].media.clips[0]"))
    }

    @Test("a template instance and a document named by its file have nested, with places continued and media as written")
    func nestsTemplateAndDocumentTimelines() throws {
        // Given
        let directory = try PackDirectory()
        try directory.addPack("shorts")
        try directory.write(
            #"{ "kind": "sequence", "params": { "clip": { "type": "video" } }, "storyline": [ { "media": { "param": "clip" } } ] }"#,
            in: "shorts",
            at: "templates/leak.json"
        )
        try directory.write(#"{ "kind": "sequence", "storyline": [ { "media": "shorts/leak.mov", "out": 1 } ] }"#, in: "shorts", at: "media/intro.json")
        let leak = directory.installed.appendingPathComponent("shorts/media/leak.mov").path
        let mediaFacts = MediaFactTable(files: [leak: ProbedMedia(kind: .video, duration: 2, fps: 24)])
        let sut = TimelineReporter(
            planner: DocumentPlanner(mediaFacts: mediaFacts, presets: Fixture.presets, library: directory.library(mediaFacts: mediaFacts))
        )
        let value = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "media": { "template": "shorts/leak", "args": { "clip": "shorts/leak.mov" } } },
              { "media": "shorts/intro.json" }
            ] }
            """#)

        // When
        let report = try sut.report(of: value)

        // Then
        let expected = #"""
            {"timeline": "1.0.0", "duration": 3, "storyline": [\#
            {"place": "storyline[0]", "id": null, "media": null, "edit": [0, 2], "drawn": [0, 2], "clip": [0, 2], "speed": 1, "transition": null, "nested": \#
            {"timeline": "1.0.0", "duration": 2, "storyline": [\#
            {"place": "storyline[0].media.storyline[0]", "id": null, "media": "shorts/leak.mov", "edit": [0, 2], "drawn": [0, 2], "clip": [0, 2], "speed": 1, "transition": null}], "clips": []}}, \#
            {"place": "storyline[1]", "id": null, "media": "shorts/intro.json", "edit": [2, 3], "drawn": [2, 3], "clip": [0, 1], "speed": 1, "transition": null, "nested": \#
            {"timeline": "1.0.0", "duration": 1, "storyline": [\#
            {"place": "storyline[1].media.storyline[0]", "id": null, "media": "shorts/leak.mov", "edit": [0, 1], "drawn": [0, 1], "clip": [0, 1], "speed": 1, "transition": null}], "clips": []}}], \#
            "clips": []}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("a document a template passes on to another template keeps the theme of the document that wrote it")
    func keepsThemeOfPassedOnArgument() throws {
        // Given
        let directory = try PackDirectory()
        try directory.addPack("shorts")
        try directory.write(
            #"""
            { "kind": "sequence", "theme": { "defaults": { "transition": "push-up" } },
              "params": { "body": { "type": "sequence" } },
              "storyline": [ { "media": { "template": "shorts/inner", "args": { "body": { "param": "body" } } } } ] }
            """#,
            in: "shorts",
            at: "templates/outer.json"
        )
        try directory.write(
            #"{ "kind": "sequence", "params": { "body": { "type": "sequence" } }, "storyline": [ { "media": { "param": "body" } } ] }"#,
            in: "shorts",
            at: "templates/inner.json"
        )
        let sut = TimelineReporter(
            planner: DocumentPlanner(mediaFacts: Fixture.mediaFacts, presets: Fixture.presets, library: directory.library())
        )
        let value = try Fixture.json(##"""
            { "kind": "sequence", "theme": { "defaults": { "transition": "flash" } },
              "storyline": [ { "media": { "template": "shorts/outer", "args": { "body":
                { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 2 }, { "solid": "#FFFFFF", "duration": 2 } ] }
              } } } ] }
            """##)

        // When
        let report = try sut.report(of: value)

        // Then
        let outer = report.machineOutput.objectValue?["storyline"]?.arrayValue?.first?.objectValue?["nested"]?.objectValue
        let inner = outer?["storyline"]?.arrayValue?.first?.objectValue?["nested"]?.objectValue
        let body = inner?["storyline"]?.arrayValue?.first?.objectValue?["nested"]?.objectValue
        let entry = try #require(body?["storyline"]?.arrayValue?.last?.objectValue)
        #expect(entry["place"] == .string("storyline[0].media.storyline[0].media.storyline[0].media.storyline[1]"))
        #expect(entry["transition"]?.objectValue?["preset"] == .string("flash"))
    }

    @Test("the text output gives one line per clip, for people")
    func writesText() throws {
        // Given
        let value = try Fixture.json(document)

        // When
        let report = try sut.report(of: value)

        // Then
        #expect(report.text.split(separator: "\n") == [
            "duration 4",
            "storyline[0]#intro  /abs/short.mp4  edit [0, 2)  drawn [0, 2.5)  clip [1, 3)  speed 1  transition none",
            "storyline[1]  -  edit [2, 4)  drawn [1.5, 4)  clip [0, 2)  speed 1  transition flash 1",
            "storyline[0]#intro.connected[0]  box  visible [0, 2.5)  animation - / pulse / -",
            "clips[0]  title  visible [0, 4)  animation pop / - / -",
            "clips[1]  audio  visible [1, 2.5)  animation none"
        ])
    }

    @Test("timeline stops wherever resolve stops, with the same message")
    func stopsWithPlan() throws {
        // Given
        let value = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "transition": "flash" } ] }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.report(of: value) }
        #expect(error == .transitionOnFirstClip(place: Place(components: [.key("storyline"), .index(0, id: nil), .key("transition")]), kind: .clip(.media(.video))))
    }
}
