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
    private let sut = TimelineReporter(planner: Fixture.planner)
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
            {"place": "storyline[0]#intro.connected[0]", "id": null, "kind": "box", "visible": [0, 2.5], "lane": 1, "parent": "storyline[0]#intro", "animation": {"entrance": null, "loop": "pulse", "exit": null}}, \#
            {"place": "clips[0]", "id": null, "kind": "title", "visible": [0, 4], "lane": 2, "parent": null, "animation": {"entrance": "pop", "loop": null, "exit": null}}, \#
            {"place": "clips[1]", "id": null, "kind": "audio", "visible": [1, 2.5], "lane": null, "parent": null, "animation": null}]}
            """#
        #expect(report.machineOutput.written == expected)
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
        #expect(error == .transitionOnFirstClip(place: Place(components: [.key("storyline"), .index(0, id: nil), .key("transition")]), kind: "video"))
    }
}
