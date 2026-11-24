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
              "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Send" }, "parent": "intro", "animation": "frames/pulse" } ] },
            { "solid": "#000000", "duration": 2, "transition": { "preset": "frames/flash", "seconds": 1 } }
          ],
          "clips": [
            { "at": [0, 4], "title": "Top", "style": "title", "lane": 2, "animation": { "preset": "frames/pop", "by": "word" } },
            { "at": 1, "media": "/abs/ding.wav" }
          ] }
        """##

    // "Total" is followed in `/abs/screen.mp4` up to media second 1.9, so a box on it from clip second 1.5 is visible
    // until the frame shown then ends.
    private let trackingReporter = TimelineReporter(
        planner: DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: Fixture.presets,
            ocr: Fixture.ocr,
            languages: nil,
            tracker: TrackerTable(
                frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes],
                followed: ["/abs/screen.mp4": 0...1.9]
            ),
            shaper: Fixture.shaper,
            library: Fixture.library
        )
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("the machine output is the timeline object FRAMES-23 gives, with places, ranges, transitions, parents and units")
    func writesMachineOutput() throws {
        // Given
        let value = try Fixture.json(document)

        // When
        let report = try sut.report(of: value)

        // Then
        let expected = #"""
            {"timeline": "0.1.0", "duration": 4, "storyline": [\#
            {"place": "storyline[0]#intro", "id": "intro", "media": "/abs/short.mp4", "edit": [0, 2], "drawn": [0, 2.5], "clip": [1, 3], "sound": null, "speed": 1, "timeRemap": false, "transition": null}, \#
            {"place": "storyline[1]", "id": null, "media": null, "edit": [2, 4], "drawn": [1.5, 4], "clip": [0, 2], "sound": null, "speed": 1, "timeRemap": false, "transition": {"preset": "frames/flash", "seconds": 1}}], \#
            "clips": [\#
            {"place": "storyline[0]#intro.connected[0]", "id": null, "kind": "rect", "visible": [0, 2], "sound": null, "lane": 1, "storyline": "storyline[0]#intro", "parent": "storyline[0]#intro", "animation": {"entrance": {"preset": "frames/pulse", "seconds": 0.25}, "loop": {"preset": "frames/pulse", "period": 1}, "exit": {"preset": "frames/pulse", "seconds": 0.25}, "by": null, "stagger": null, "order": null}}, \#
            {"place": "clips[0]", "id": null, "kind": "title", "visible": [0, 4], "sound": null, "lane": 2, "storyline": null, "parent": null, "animation": {"entrance": {"preset": "frames/pop", "seconds": 0.25}, "loop": null, "exit": null, "by": "word", "stagger": 0.12, "order": "forward"}}, \#
            {"place": "clips[1]", "id": null, "kind": "audio", "visible": [1, 2.5], "sound": null, "lane": null, "storyline": null, "parent": null, "animation": null}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("a resolved document reports the ranges it holds, with no preset names, its media pinned and no audio clips")
    func reportsResolvedDocument() throws {
        // Given
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())

        // When
        let report = sut.report(of: resolved)

        // Then
        let expected = #"""
            {"timeline": "0.1.0", "duration": 4, "storyline": [\#
            {"place": "storyline[0]#intro", "id": "intro", "media": "/abs/short.mp4", "edit": [0, 2], "drawn": [0, 2.5], "clip": [1, 3], "sound": null, "speed": 1, "timeRemap": false, "transition": null}, \#
            {"place": "storyline[1]", "id": null, "media": null, "edit": [2, 4], "drawn": [1.5, 4], "clip": [0, 2], "sound": null, "speed": 1, "timeRemap": false, "transition": {"preset": null, "seconds": 1}}], \#
            "clips": [\#
            {"place": "storyline[0]#intro.connected[0]", "id": null, "kind": "rect", "visible": [0, 2], "sound": null, "lane": 1, "storyline": "storyline[0]#intro", "parent": "storyline[0]#intro", "animation": {"entrance": {"preset": null, "seconds": 0.25}, "loop": {"preset": null, "period": 1}, "exit": {"preset": null, "seconds": 0.25}, "by": null, "stagger": null, "order": null}}, \#
            {"place": "clips[0]", "id": null, "kind": "title", "visible": [0, 4], "sound": null, "lane": 2, "storyline": null, "parent": null, "animation": {"entrance": {"preset": null, "seconds": 0.25}, "loop": null, "exit": null, "by": "word", "stagger": 0.12, "order": "forward"}}]}
            """#
        #expect(report.machineOutput.written == expected)
        #expect(report.text.split(separator: "\n").last == "clips[0]  title  visible [0, 4)  sound -  lane 2  parent -  animation 0.25s / - / -")
    }

    @Test("a title's `order` is written beside `by` and `stagger`, from the document and from its resolved document alike")
    func writesUnitOrder() throws {
        // Given
        let value = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/short.mp4", "in": 1, "out": 3 } ],
              "clips": [ { "at": [0, 2], "title": "Top", "style": "title", "animation": { "preset": "frames/pop", "by": "line", "stagger": 0.2, "order": "edges" } } ] }
            """#)
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(value), hashes: FileHashTable())

        // When
        let report = try sut.report(of: value)
        let resolvedReport = sut.report(of: resolved)

        // Then
        let animation = #"{"entrance": {"preset": "frames/pop", "seconds": 0.25}, "loop": null, "exit": null, "by": "line", "stagger": 0.2, "order": "edges"}"#
        let resolvedAnimation = #"{"entrance": {"preset": null, "seconds": 0.25}, "loop": null, "exit": null, "by": "line", "stagger": 0.2, "order": "edges"}"#
        #expect(report.machineOutput.written.contains(#""animation": \#(animation)}"#))
        #expect(resolvedReport.machineOutput.written.contains(#""animation": \#(resolvedAnimation)}"#))
    }

    @Test("a storyline page of a PDF has its media as the {file, page} object, a PDF of one page named as a file too")
    func writesPageMedia() throws {
        // Given
        let value = try Fixture.json(#"""
            { "kind": "sequence",
              "storyline": [
                { "media": { "file": "/abs/deck.pdf", "page": 3 }, "duration": 2 },
                { "media": "/abs/logo.pdf", "duration": 1 }
              ] }
            """#)

        // When
        let report = try sut.report(of: value)
        let resolved = sut.report(of: try ResolvedSequence(plan: Fixture.documentPlanner.plan(value), hashes: FileHashTable()))

        // Then
        let media = { (report: TimelineReport) in
            report.machineOutput.objectValue?["storyline"]?.arrayValue?.map { $0.objectValue?["media"]?.written }
        }
        let expected = [#"{"file": "/abs/deck.pdf", "page": 3}"#, #"{"file": "/abs/logo.pdf", "page": 1}"#]
        #expect(media(report) == expected)
        #expect(media(resolved) == expected)
        #expect(report.text.contains("/abs/deck.pdf page 3"))
    }

    @Test("a resolved compound clip reports its nested sequence, with places continued")
    func nestsResolvedCompoundTimeline() throws {
        // Given
        let value = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "media": { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "solid": "#000000", "duration": 2 } ],
                           "clips": [ { "title": "a", "style": "title" } ] } }
            ] }
            """##)
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(value), hashes: FileHashTable())

        // When
        let report = sut.report(of: resolved)

        // Then
        #expect(report == (try sut.report(of: value)))
    }

    @Test("times and lengths are written to the nearest microsecond, in their shortest form, in both outputs")
    func roundsTimes() throws {
        // Given
        let value = try Fixture.json(##"""
            { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "solid": "#000000", "duration": 0.1 }, { "solid": "#FFFFFF", "duration": 0.2 } ] }
            """##)

        // When
        let report = try sut.report(of: value)

        // Then
        let output = report.machineOutput.objectValue
        #expect(report.duration != 0.3)
        #expect(output?["duration"] == .number(0.3))
        #expect(output?["storyline"]?.arrayValue?[1].objectValue?["edit"] == .array([.number(0.1), .number(0.3)]))
        #expect(report.text.hasPrefix("duration 0.3\n"))
        #expect(report.text.contains("edit [0.1, 0.3)"))
    }

    @Test("an entry whose media is a compound clip has nested, the timeline object of the document inside")
    func nestsCompoundTimeline() throws {
        // Given
        let value = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "media": { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "solid": "#000000", "duration": 2 } ],
                           "clips": [ { "title": "a", "style": "title" } ] } }
            ] }
            """##)

        // When
        let report = try sut.report(of: value)

        // Then
        let entry = try #require(report.machineOutput.objectValue?["storyline"]?.arrayValue?.first?.objectValue)
        let nested = try #require(entry["nested"]?.objectValue)
        #expect(entry["media"] == .null)
        #expect(entry["clip"] == .array([.number(0), .number(2)]))
        #expect(nested["timeline"] == .string("0.1.0"))
        #expect(nested["clips"]?.arrayValue?.first?.objectValue?["place"] == .string("storyline[0].media.clips[0]"))
    }

    @Test("a template instance and a document named by its file have nested, with places continued and media as written")
    func nestsTemplateAndDocumentTimelines() throws {
        // Given
        let directory = try PackDirectory()
        try directory.addPack("shorts")
        try directory.write(
            #"{ "kind": "sequence", "params": { "clip": { "type": "video", "description": "the clip" } }, "storyline": [ { "media": { "param": "clip" } } ] }"#,
            in: "shorts",
            at: "templates/leak.json"
        )
        try directory.write(#"{ "kind": "sequence", "storyline": [ { "media": "shorts/leak.mov", "out": 1 } ] }"#, in: "shorts", at: "media/intro.json")
        let leak = directory.installed.appendingPathComponent("shorts/media/leak.mov").path
        let mediaFacts = MediaFactTable(files: [leak: ProbedMedia(kind: .video, duration: 2, fps: 24, size: Size(width: 1080, height: 1920))])
        let sut = TimelineReporter(
            planner: DocumentPlanner(
                mediaFacts: mediaFacts,
                presets: Fixture.presets,
                ocr: Fixture.ocr,
                languages: nil,
                tracker: Fixture.tracker,
                shaper: Fixture.shaper,
                library: directory.library(mediaFacts: mediaFacts)
            )
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
            {"timeline": "0.1.0", "duration": 3, "storyline": [\#
            {"place": "storyline[0]", "id": null, "media": null, "edit": [0, 2], "drawn": [0, 2], "clip": [0, 2], "sound": null, "speed": 1, "timeRemap": false, "transition": null, "nested": \#
            {"timeline": "0.1.0", "duration": 2, "storyline": [\#
            {"place": "storyline[0].media.storyline[0]", "id": null, "media": "shorts/leak.mov", "edit": [0, 2], "drawn": [0, 2], "clip": [0, 2], "sound": null, "speed": 1, "timeRemap": false, "transition": null}], "clips": []}}, \#
            {"place": "storyline[1]", "id": null, "media": "shorts/intro.json", "edit": [2, 3], "drawn": [2, 3], "clip": [0, 1], "sound": null, "speed": 1, "timeRemap": false, "transition": null, "nested": \#
            {"timeline": "0.1.0", "duration": 1, "storyline": [\#
            {"place": "storyline[1].media.storyline[0]", "id": null, "media": "shorts/leak.mov", "edit": [0, 1], "drawn": [0, 1], "clip": [0, 1], "sound": null, "speed": 1, "timeRemap": false, "transition": null}], "clips": []}}], \#
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
            { "kind": "sequence", "theme": { "defaults": { "transition": "frames/push-up" } },
              "params": { "body": { "type": "sequence", "description": "the body" } },
              "storyline": [ { "media": { "template": "shorts/inner", "args": { "body": { "param": "body" } } } } ] }
            """#,
            in: "shorts",
            at: "templates/outer.json"
        )
        try directory.write(
            #"{ "kind": "sequence", "params": { "body": { "type": "sequence", "description": "the body" } }, "storyline": [ { "media": { "param": "body" } } ] }"#,
            in: "shorts",
            at: "templates/inner.json"
        )
        let sut = TimelineReporter(
            planner: DocumentPlanner(
                mediaFacts: Fixture.mediaFacts,
                presets: Fixture.presets,
                ocr: Fixture.ocr,
                languages: nil,
                tracker: Fixture.tracker,
                shaper: Fixture.shaper,
                library: directory.library()
            )
        )
        let value = try Fixture.json(##"""
            { "kind": "sequence", "theme": { "defaults": { "transition": "frames/flash" } },
              "storyline": [ { "media": { "template": "shorts/outer", "args": { "body":
                { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "solid": "#000000", "duration": 2 }, { "solid": "#FFFFFF", "duration": 2 } ] }
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
        #expect(entry["transition"]?.objectValue?["preset"] == .string("frames/flash"))
    }

    @Test("a document a template wraps in its own before passing it on keeps the theme of the document that wrote it")
    func keepsThemeOfWrappedArgument() throws {
        // Given
        let directory = try PackDirectory()
        try directory.addPack("shorts")
        try directory.write(
            ##"""
            { "kind": "sequence", "theme": { "defaults": { "transition": "frames/push-up" } },
              "params": { "body": { "type": "sequence", "description": "the body" } },
              "storyline": [ { "media": { "template": "shorts/inner", "args": { "body":
                { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "solid": "#000000", "duration": 2 }, { "media": { "param": "body" } } ] }
              } } } ] }
            """##,
            in: "shorts",
            at: "templates/outer.json"
        )
        try directory.write(
            #"{ "kind": "sequence", "params": { "body": { "type": "sequence", "description": "the body" } }, "storyline": [ { "media": { "param": "body" } } ] }"#,
            in: "shorts",
            at: "templates/inner.json"
        )
        let sut = TimelineReporter(
            planner: DocumentPlanner(
                mediaFacts: Fixture.mediaFacts,
                presets: Fixture.presets,
                ocr: Fixture.ocr,
                languages: nil,
                tracker: Fixture.tracker,
                shaper: Fixture.shaper,
                library: directory.library()
            )
        )
        let value = try Fixture.json(##"""
            { "kind": "sequence", "theme": { "defaults": { "transition": "frames/flash" } },
              "storyline": [ { "media": { "template": "shorts/outer", "args": { "body":
                { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "solid": "#000000", "duration": 2 }, { "solid": "#FFFFFF", "duration": 2 } ] }
              } } } ] }
            """##)

        // When
        let report = try sut.report(of: value)

        // Then
        let outer = report.machineOutput.objectValue?["storyline"]?.arrayValue?.first?.objectValue?["nested"]?.objectValue
        let inner = outer?["storyline"]?.arrayValue?.first?.objectValue?["nested"]?.objectValue
        let wrapper = inner?["storyline"]?.arrayValue?.first?.objectValue?["nested"]?.objectValue
        let wrapperEntry = try #require(wrapper?["storyline"]?.arrayValue?.last?.objectValue)
        let body = wrapperEntry["nested"]?.objectValue
        let bodyEntry = try #require(body?["storyline"]?.arrayValue?.last?.objectValue)
        #expect(wrapperEntry["transition"]?.objectValue?["preset"] == .string("frames/push-up"))
        #expect(bodyEntry["place"] == .string("storyline[0].media.storyline[0].media.storyline[0].media.storyline[1].media.storyline[1]"))
        #expect(bodyEntry["transition"]?.objectValue?["preset"] == .string("frames/flash"))
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
            "storyline[0]#intro  /abs/short.mp4  edit [0, 2)  drawn [0, 2.5)  clip [1, 3)  sound -  speed 1  transition none",
            "storyline[1]  -  edit [2, 4)  drawn [1.5, 4)  clip [0, 2)  sound -  speed 1  transition frames/flash 1",
            "storyline[0]#intro.connected[0]  rect  visible [0, 2)  sound -  lane 1  parent storyline[0]#intro  animation frames/pulse / frames/pulse / frames/pulse",
            "clips[0]  title  visible [0, 4)  sound -  lane 2  parent -  animation frames/pop / - / -",
            "clips[1]  audio  visible [1, 2.5)  sound -  lane -  parent -  animation none"
        ])
    }

    @Test(
        "sound is the range a storyline clip's or visual media clip's sound plays over, its split applied, from a document and resolved"
    )
    func reportsSound() throws {
        // Given
        let value = try Fixture.json(#"""
            { "kind": "sequence",
              "storyline": [
                { "media": "/abs/run.mp4", "in": 0, "out": 4, "split": { "after": 1 },
                  "connected": [ { "media": "/abs/run.mp4", "at": [1, 3], "in": 2, "split": { "before": 1 } }, { "media": "/abs/short.mp4", "at": [0, 1] } ] },
                { "media": "/abs/run.mp4", "in": 4, "out": 8 },
                { "media": "/abs/short.mp4", "in": 0, "out": 2 } ],
              "clips": [ { "media": "/abs/bgm.m4a", "at": [0, 2] }, { "media": "/abs/run.mp4", "picture": false, "at": [0, 2] } ] }
            """#)
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(value), hashes: FileHashTable())

        // When
        let report = try sut.report(of: value)

        // Then
        let range = { (start: Double, end: Double) in JSONValue.array([.number(start), .number(end)]) }
        let storyline = report.machineOutput.objectValue?["storyline"]?.arrayValue?.compactMap(\.objectValue) ?? []
        let clips = report.machineOutput.objectValue?["clips"]?.arrayValue?.compactMap(\.objectValue) ?? []
        #expect(storyline.map { $0["sound"] } == [range(0, 5), range(4, 8), .null])
        #expect(clips.map { $0["sound"] } == [range(0, 3), .null, .null, .null])
        #expect(report.text.split(separator: "\n")[1].contains("  clip [0, 4)  sound [0, 5)  "))
        #expect(sut.report(of: resolved).storyline == report.storyline)
        #expect(sut.report(of: resolved).clips.map(\.sound) == [TimeRange(start: 0, end: 3), nil])
    }

    @Test("a connected clip names the storyline clip it belongs to, apart from the clip it is parented to")
    func reportsStorylineApartFromParent() throws {
        // Given
        let value = try Fixture.json(#"""
            { "kind": "sequence",
              "storyline": [ { "media": "/abs/short.mp4", "in": 0, "out": 2,
                "connected": [ { "id": "box", "at": [0, 1], "shape": "rect", "fill": "#FFFFFF", "area": [0, 0, 10, 10] },
                               { "at": [0, 1], "title": "a", "style": "title", "lane": 3, "parent": "box", "position": [0, 0] } ] } ] }
            """#)

        // When
        let report = try sut.report(of: value)

        // Then
        let entries = report.machineOutput.objectValue?["clips"]?.arrayValue?.compactMap(\.objectValue) ?? []
        #expect(entries.map { $0["storyline"] } == [.string("storyline[0]"), .string("storyline[0]")])
        #expect(entries.map { $0["parent"] } == [.null, .string("storyline[0].connected[0]#box")])
        #expect(report.text.split(separator: "\n").last
            == "storyline[0].connected[1]  title  visible [0, 1)  sound -  lane 3  parent storyline[0].connected[0]#box  animation none")
    }

    @Test("a time-remapped storyline clip reports that it is remapped in place of its speed, and timeRemap true")
    func reportsTimeRemap() throws {
        // Given
        let value = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "media": "/abs/short.mp4", "in": 0, "out": 2, "keyframes": [ { "at": 0, "timeRemap": 3 }, { "at": 2, "timeRemap": 1 } ] },
              { "media": "/abs/short.mp4", "in": 0, "out": 2 } ] }
            """#)

        // When
        let report = try sut.report(of: value)

        // Then
        let entries = report.machineOutput.objectValue?["storyline"]?.arrayValue?.compactMap(\.objectValue) ?? []
        #expect(entries.map { $0["timeRemap"] } == [.bool(true), .bool(false)])
        #expect(entries.map { $0["speed"] } == [.number(1), .number(1)])
        let lines = report.text.split(separator: "\n").dropFirst()
        #expect(lines.map { $0.contains("  time-remapped  ") } == [true, false])
        #expect(lines.map { $0.contains("  speed 1  ") } == [false, true])
    }

    @Test("a text area found by OCR, a track, a title and a shape report, with the window tracking leaves")
    func reportsAreasAndTracking() throws {
        // Given
        let value = try Fixture.json(tracked)

        // When
        let report = try trackingReporter.report(of: value)

        // Then
        let expected = #"""
            {"timeline": "0.1.0", "duration": 2, "storyline": [\#
            {"place": "storyline[0]#screen", "id": "screen", "media": "/abs/screen.mp4", "edit": [0, 2], "drawn": [0, 2], "clip": [1, 3], "sound": null, "speed": 1, "timeRemap": false, "transition": null}], \#
            "clips": [\#
            {"place": "storyline[0]#screen.connected[0]", "id": null, "kind": "rect", "visible": [0.5, 1], "sound": null, "lane": 1, "storyline": "storyline[0]#screen", "parent": "storyline[0]#screen", "animation": null}, \#
            {"place": "clips[0]", "id": null, "kind": "title", "visible": [0, 2], "sound": null, "lane": 1, "storyline": null, "parent": null, "animation": null}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("a clip's parent is reported by its place, a storyline clip or any other clip, from a document and resolved")
    func reportsParentPlaces() throws {
        // Given
        let value = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "shot", "media": "/abs/short.mp4", "in": 0, "out": 2,
                "connected": [ { "id": "bar", "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 100, 20], "parent": "shot" } ] } ],
              "clips": [ { "at": [0, 2], "title": "a", "style": "title", "parent": "bar", "position": [10, 10] },
                         { "at": [0, 2], "title": "b", "style": "title" } ] }
            """#)
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(value), hashes: FileHashTable())

        // When
        let planned = try sut.report(of: value)
        let read = sut.report(of: resolved)

        // Then
        let parents = ["storyline[0]#shot", "storyline[0]#shot.connected[0]#bar", nil]
        #expect(planned.clips.map(\.parent) == parents)
        #expect(read.clips.map(\.parent) == parents)
    }

    @Test("timeline stops wherever resolve stops, with the same message")
    func stopsWithPlan() throws {
        // Given
        let value = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "transition": "frames/flash" } ] }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.report(of: value) }
        #expect(error == .transitionOnFirstClip(place: Place(components: [.key("storyline"), .index(0, id: nil), .key("transition")]), kind: .clip(.media(.video))))
    }

    // MARK: - Private
    // A box on the text "Total", tracked, and a title over the whole sequence.
    private var tracked: String {
        #"""
        { "kind": "sequence", "theme": { "baseWidth": 1206 },
          "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 1, "out": 3,
            "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Total" }, "parent": "screen", "at": [1.5, 3], "track": { "text": "Total" } } ] } ],
          "clips": [ { "at": [0, 2], "title": "Pay now", "style": "title" } ] }
        """#
    }
}
