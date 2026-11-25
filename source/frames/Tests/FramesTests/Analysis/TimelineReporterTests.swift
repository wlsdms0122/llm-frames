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
              "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "area": [400, 1200, 200, 60], "parent": "intro", "animation": "frames/pulse" } ] },
            { "solid": "#000000", "duration": 2, "transition": { "preset": "frames/flash", "seconds": 1 } }
          ],
          "clips": [
            { "at": [0, 4], "title": "Top", "style": "title", "lane": 2, "animation": { "preset": "frames/pop", "by": "word" } },
            { "at": 1, "media": "/abs/ding.wav" }
          ] }
        """##

    // The target is followed in `/abs/screen.mp4` up to media second 1.9, so a box on it from clip second 1.5 is visible
    // until the frame shown then ends.
    private let tracker = TrackerTable(
        frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes],
        followed: ["/abs/screen.mp4": 0...1.9]
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
            {"place": "storyline[0]#intro", "id": "intro", "kind": "video", "media": "/abs/short.mp4", "page": null, "edit": [0, 2], "drawn": [0, 2.5], "clip": [1, 3], "sound": null, "speed": 1, "timeRemap": false, "transition": null, "fps": null, "instant": 0, "clock": {"clip": "storyline[0]#intro", "origin": -1, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "media", "clip": "storyline[0]#intro"}, "tracked": {"clip": "storyline[0]#intro", "first": 1, "last": 3}}, \#
            {"place": "storyline[1]", "id": null, "kind": "solid", "media": null, "page": null, "edit": [2, 4], "drawn": [1.5, 4], "clip": [0, 2], "sound": null, "speed": 1, "timeRemap": false, "transition": {"preset": "frames/flash", "seconds": 1}, "fps": null, "instant": 2, "clock": {"clip": "storyline[1]", "origin": 2, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "output", "clip": null}, "tracked": null}], \#
            "clips": [\#
            {"place": "storyline[0]#intro.connected[0]", "id": null, "kind": "rect", "media": null, "page": null, "visible": [0, 2], "sound": null, "lane": 1, "storyline": "storyline[0]#intro", "parent": "storyline[0]#intro", "animation": {"entrance": {"preset": "frames/pulse", "seconds": 0.25}, "loop": {"preset": "frames/pulse", "period": 1}, "exit": {"preset": "frames/pulse", "seconds": 0.25}, "by": null, "stagger": null, "order": null}, "fps": null, "instant": 0, "clock": {"clip": "storyline[0]#intro", "origin": -1, "speed": 1}, "space": {"kind": "media", "clip": "storyline[0]#intro"}, "ownSpace": {"kind": "media", "clip": "storyline[0]#intro"}, "tracked": {"clip": "storyline[0]#intro", "first": 1, "last": 3}}, \#
            {"place": "clips[0]", "id": null, "kind": "title", "media": null, "page": null, "visible": [0, 4], "sound": null, "lane": 2, "storyline": null, "parent": null, "animation": {"entrance": {"preset": "frames/pop", "seconds": 0.25}, "loop": null, "exit": null, "by": "word", "stagger": 0.12, "order": "forward"}, "fps": null, "instant": 0, "clock": {"clip": null, "origin": 0, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "box", "clip": "clips[0]"}, "tracked": null}, \#
            {"place": "clips[1]", "id": null, "kind": "audio", "media": "/abs/ding.wav", "page": null, "visible": [1, 2.5], "sound": null, "lane": null, "storyline": null, "parent": null, "animation": null, "fps": null, "instant": 1, "clock": {"clip": null, "origin": 0, "speed": 1}, "space": null, "ownSpace": null, "tracked": null}]}
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
            {"place": "storyline[0]#intro", "id": "intro", "kind": "video", "media": "/abs/short.mp4", "page": null, "edit": [0, 2], "drawn": [0, 2.5], "clip": [1, 3], "sound": null, "speed": 1, "timeRemap": false, "transition": null, "fps": null, "instant": null, "clock": {"clip": null, "origin": 0, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "media", "clip": "storyline[0]#intro"}, "tracked": null}, \#
            {"place": "storyline[1]", "id": null, "kind": "solid", "media": null, "page": null, "edit": [2, 4], "drawn": [1.5, 4], "clip": [0, 2], "sound": null, "speed": 1, "timeRemap": false, "transition": {"preset": null, "seconds": 1}, "fps": null, "instant": null, "clock": {"clip": null, "origin": 0, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "output", "clip": null}, "tracked": null}], \#
            "clips": [\#
            {"place": "storyline[0]#intro.connected[0]", "id": null, "kind": "rect", "media": null, "page": null, "visible": [0, 2], "sound": null, "lane": 1, "storyline": "storyline[0]#intro", "parent": "storyline[0]#intro", "animation": {"entrance": {"preset": null, "seconds": 0.25}, "loop": {"preset": null, "period": 1}, "exit": {"preset": null, "seconds": 0.25}, "by": null, "stagger": null, "order": null}, "fps": null, "instant": null, "clock": {"clip": null, "origin": 0, "speed": 1}, "space": {"kind": "media", "clip": "storyline[0]#intro"}, "ownSpace": {"kind": "media", "clip": "storyline[0]#intro"}, "tracked": null}, \#
            {"place": "clips[0]", "id": null, "kind": "title", "media": null, "page": null, "visible": [0, 4], "sound": null, "lane": 2, "storyline": null, "parent": null, "animation": {"entrance": {"preset": null, "seconds": 0.25}, "loop": null, "exit": null, "by": "word", "stagger": 0.12, "order": "forward"}, "fps": null, "instant": null, "clock": {"clip": null, "origin": 0, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "box", "clip": "clips[0]"}, "tracked": null}]}
            """#
        #expect(report.machineOutput.written == expected)
        #expect(report.text.split(separator: "\n").last == "clips[0]  title  -  visible [0, 4)  sound -  lane 2  parent -  animation 0.25s / - / -")
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
        #expect(report.machineOutput.written.contains(#""animation": \#(animation), "fps""#))
        #expect(resolvedReport.machineOutput.written.contains(#""animation": \#(resolvedAnimation), "fps""#))
    }

    @Test("a storyline page of a PDF has its media as the PDF's path and its page apart, a PDF of one page named as a file too")
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
            report.machineOutput.objectValue?["storyline"]?.arrayValue?.compactMap(\.objectValue).map { entry in
                [entry["kind"], entry["media"], entry["page"]]
            }
        }
        let expected: [[JSONValue?]] = [
            [.string("page"), .string("/abs/deck.pdf"), .number(3)],
            [.string("page"), .string("/abs/logo.pdf"), .number(1)]
        ]
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
        #expect(withoutClocks(report.machineOutput) == withoutClocks(try sut.report(of: value).machineOutput))
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

    @Test("every entry names its kind, its media by the pinned path, a pack media name and an image sequence included, its page and an image sequence's rate")
    func namesKindMediaAndPage() throws {
        // Given
        let directory = try PackDirectory()
        try directory.addPack("shorts")
        let leak = directory.installed.appendingPathComponent("shorts/media/leak.mov").path
        let mediaFacts = MediaFactTable(
            files: [
                leak: ProbedMedia(kind: .video, duration: 2, fps: 24, size: Size(width: 1080, height: 1920)),
                "/abs/card.png": ProbedMedia(kind: .image, size: Size(width: 1080, height: 1350))
            ],
            imageSequences: ["/abs/frames": Fixture.imageSequenceFiles],
            pages: Fixture.pages
        )
        let planner = DocumentPlanner(
            mediaFacts: mediaFacts,
            presets: Fixture.presets,
            shaper: Fixture.shaper,
            library: directory.library(mediaFacts: mediaFacts)
        )
        let sut = TimelineReporter(planner: planner)
        let value = try Fixture.json(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [
                { "media": { "imageSequence": "/abs/frames", "fps": 10 }, "in": 0, "out": 1,
                  "connected": [ { "media": "shorts/leak.mov", "at": 0 } ] },
                { "media": "/abs/card.png", "duration": 1 } ],
              "clips": [ { "media": { "file": "/abs/deck.pdf", "page": 3 }, "at": [0, 2] }, { "at": [0, 2], "title": "Top", "style": "title" } ] }
            """#)

        // When
        let report = try sut.report(of: value)
        let resolved = sut.report(of: try ResolvedSequence(plan: planner.plan(value), hashes: FileHashTable()))

        // Then
        let entries = { (report: TimelineReport) -> [[JSONValue?]] in
            let output = report.machineOutput.objectValue
            return ["storyline", "clips"].flatMap { output?[$0]?.arrayValue?.compactMap(\.objectValue) ?? [] }
                .map { [$0["kind"], $0["media"], $0["page"], $0["fps"]] }
        }
        let expected: [[JSONValue?]] = [
            [.string("video"), .string("/abs/frames"), .null, .number(10)],
            [.string("image"), .string("/abs/card.png"), .null, .null],
            [.string("video"), .string(leak), .null, .null],
            [.string("page"), .string("/abs/deck.pdf"), .number(3), .null],
            [.string("title"), .null, .null, .null]
        ]
        #expect(entries(report) == expected)
        #expect(entries(resolved) == expected.map { [$0[0], $0[1], $0[2], .null] })
    }

    @Test("a template instance and a document named by its file have nested, with places continued and media by its pinned path")
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
            {"place": "storyline[0]", "id": null, "kind": "compound", "media": null, "page": null, "edit": [0, 2], "drawn": [0, 2], "clip": [0, 2], "sound": null, "speed": 1, "timeRemap": false, "transition": null, "fps": null, "instant": 0, "clock": {"clip": "storyline[0]", "origin": 0, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "media", "clip": "storyline[0]"}, "tracked": null, "nested": \#
            {"timeline": "0.1.0", "duration": 2, "storyline": [\#
            {"place": "storyline[0].media.storyline[0]", "id": null, "kind": "video", "media": "\#(leak)", "page": null, "edit": [0, 2], "drawn": [0, 2], "clip": [0, 2], "sound": null, "speed": 1, "timeRemap": false, "transition": null, "fps": null, "instant": 0, "clock": {"clip": "storyline[0].media.storyline[0]", "origin": 0, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "media", "clip": "storyline[0].media.storyline[0]"}, "tracked": {"clip": "storyline[0].media.storyline[0]", "first": 0, "last": 2}}], "clips": []}}, \#
            {"place": "storyline[1]", "id": null, "kind": "compound", "media": null, "page": null, "edit": [2, 3], "drawn": [2, 3], "clip": [0, 1], "sound": null, "speed": 1, "timeRemap": false, "transition": null, "fps": null, "instant": 2, "clock": {"clip": "storyline[1]", "origin": 2, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "media", "clip": "storyline[1]"}, "tracked": null, "nested": \#
            {"timeline": "0.1.0", "duration": 1, "storyline": [\#
            {"place": "storyline[1].media.storyline[0]", "id": null, "kind": "video", "media": "\#(leak)", "page": null, "edit": [0, 1], "drawn": [0, 1], "clip": [0, 1], "sound": null, "speed": 1, "timeRemap": false, "transition": null, "fps": null, "instant": 0, "clock": {"clip": "storyline[1].media.storyline[0]", "origin": 0, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "media", "clip": "storyline[1].media.storyline[0]"}, "tracked": {"clip": "storyline[1].media.storyline[0]", "first": 0, "last": 1}}], "clips": []}}], \#
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
            "storyline[0]#intro  video  /abs/short.mp4  edit [0, 2)  drawn [0, 2.5)  clip [1, 3)  sound -  speed 1  transition none",
            "storyline[1]  solid  -  edit [2, 4)  drawn [1.5, 4)  clip [0, 2)  sound -  speed 1  transition frames/flash 1",
            "storyline[0]#intro.connected[0]  rect  -  visible [0, 2)  sound -  lane 1  parent storyline[0]#intro  animation frames/pulse / frames/pulse / frames/pulse",
            "clips[0]  title  -  visible [0, 4)  sound -  lane 2  parent -  animation frames/pop / - / -",
            "clips[1]  audio  /abs/ding.wav  visible [1, 2.5)  sound -  lane -  parent -  animation none"
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
        #expect(sut.report(of: resolved).storyline.map(\.sound) == report.storyline.map(\.sound))
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
            == "storyline[0].connected[1]  title  -  visible [0, 1)  sound -  lane 3  parent storyline[0].connected[0]#box  animation none")
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
        let report = try sut.report(of: value)

        // Then
        let expected = #"""
            {"timeline": "0.1.0", "duration": 2, "storyline": [\#
            {"place": "storyline[0]#screen", "id": "screen", "kind": "video", "media": "/abs/screen.mp4", "page": null, "edit": [0, 2], "drawn": [0, 2], "clip": [1, 3], "sound": null, "speed": 1, "timeRemap": false, "transition": null, "fps": null, "instant": 0, "clock": {"clip": "storyline[0]#screen", "origin": -1, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "media", "clip": "storyline[0]#screen"}, "tracked": {"clip": "storyline[0]#screen", "first": 1, "last": 3}}], \#
            "clips": [\#
            {"place": "storyline[0]#screen.connected[0]", "id": null, "kind": "rect", "media": null, "page": null, "visible": [0.5, 1], "sound": null, "lane": 1, "storyline": "storyline[0]#screen", "parent": "storyline[0]#screen", "animation": null, "fps": null, "instant": 0.5, "clock": {"clip": "storyline[0]#screen", "origin": -1, "speed": 1}, "space": {"kind": "media", "clip": "storyline[0]#screen"}, "ownSpace": {"kind": "media", "clip": "storyline[0]#screen"}, "tracked": {"clip": "storyline[0]#screen", "first": 1, "last": 3}}, \#
            {"place": "clips[0]", "id": null, "kind": "title", "media": null, "page": null, "visible": [0, 2], "sound": null, "lane": 1, "storyline": null, "parent": null, "animation": null, "fps": null, "instant": 0, "clock": {"clip": null, "origin": 0, "speed": 1}, "space": {"kind": "output", "clip": null}, "ownSpace": {"kind": "box", "clip": "clips[0]"}, "tracked": null}]}
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

    @Test(
        "timeline at a time gives each clip's clip time and the frame its time map shows, inside its window and outside it",
        arguments: [
            (-1, [-1.5, -1.5], [0, 3, 0, 0]),
            (0.3, [1.1, -0.2], [1, 3, 0, 0]),
            (1.8, [4.1, 1.3], [1.5, 1, 1, 1]),
            (2.2, [4.9, 1.7], [1.5, 1, 0.5, 1.5]),
            (10, [20.5, 9.5], [1.5, 1, 0.5, 1.5])
        ] as [(Double, [Double], [Double])]
    )
    func reportsTimeMapsAtTime(
        time: Double,
        clipTimes: [Double],
        mediaTimes: [Double]
    ) throws {
        // Given
        let value = try Fixture.json(timeMapped)
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(value), hashes: FileHashTable())

        // When
        let report = try sut.report(of: value, at: time)
        let resolvedReport = sut.report(of: resolved, at: time)

        // Then
        let output = report.machineOutput.objectValue
        let storyline = output?["storyline"]?.arrayValue?.compactMap(\.objectValue) ?? []
        let clips = output?["clips"]?.arrayValue?.compactMap(\.objectValue) ?? []
        #expect(output?["time"] == .number(time))
        #expect(storyline.map { $0["clipTime"]?.numberValue } == clipTimes)
        #expect((storyline + clips).map { $0["mediaTime"]?.numberValue } == mediaTimes)
        #expect(clips.allSatisfy { $0["clipTime"] == nil })
        #expect(withoutClocks(resolvedReport.machineOutput) == withoutClocks(report.machineOutput))
    }

    @Test("timeline at a time gives a clip without media no media time, and without a time no clip time or media time")
    func reportsNoMediaTime() throws {
        // Given
        let value = try Fixture.json(document)

        // When
        let report = try sut.report(of: value, at: 1)
        let untimed = try sut.report(of: value)

        // Then
        let entries = { (report: TimelineReport) in
            let output = report.machineOutput.objectValue
            return ["storyline", "clips"].flatMap { output?[$0]?.arrayValue?.compactMap(\.objectValue) ?? [] }
        }
        #expect(entries(report).map { $0["mediaTime"] } == [.number(2), .null, .null, .null, .number(0)])
        #expect(entries(untimed).allSatisfy { $0["clipTime"] == nil && $0["mediaTime"] == nil })
        #expect(untimed.machineOutput.objectValue?["time"] == nil)
        #expect(report.text.split(separator: "\n").prefix(3) == [
            "duration 4",
            "at 1",
            "storyline[0]#intro  video  /abs/short.mp4  edit [0, 2)  drawn [0, 2.5)  clip [1, 3)  sound -  speed 1  transition none  clip time 2  media time 2"
        ])
    }

    @Test("timeline at a time reports a compound clip's nested document at the nested time its clip shows")
    func reportsNestedTimeline() throws {
        // Given
        let value = try Fixture.json(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [
              { "media": { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "media": "/abs/leak.mov", "in": 0, "out": 2 } ] },
                "in": 0.5, "out": 1.5 } ] }
            """#)
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(value), hashes: FileHashTable())

        // When
        let report = try sut.report(of: value, at: 0.2)
        let before = try sut.report(of: value, at: -1)

        // Then
        let times = { (report: TimelineReport) -> [Double?] in
            let entry = report.machineOutput.objectValue?["storyline"]?.arrayValue?.first?.objectValue
            let nested = entry?["nested"]?.objectValue
            let inner = nested?["storyline"]?.arrayValue?.first?.objectValue
            return [entry?["clipTime"], entry?["mediaTime"], nested?["time"], inner?["clipTime"], inner?["mediaTime"]]
                .map { $0?.numberValue }
        }
        #expect(times(report) == [0.7, 0.7, 0.7, 0.7, 0.5])
        #expect(times(before) == [-0.5, 0, 0, 0, 0])
        #expect(withoutClocks(sut.report(of: resolved, at: 0.2).machineOutput) == withoutClocks(report.machineOutput))
    }

    @Test("timeline at a time gives a drawn clip the media time evaluate names for the frame it draws, and one that draws nothing a media time too")
    func agreesWithEvaluation() throws {
        // Given
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(timeMapped)), hashes: FileHashTable())

        // When
        let report = sut.report(of: resolved, at: 1.2)
        let evaluation = try EvaluationReporter().report(of: resolved, at: 1.2)

        // Then
        let entries = report.storyline.map { ($0.place, $0.time?.mediaTime) } + report.clips.map { ($0.place, $0.time?.mediaTime) }
        let drawn = Dictionary(
            evaluation.items.compactMap { item in item.frame.flatMap { frame in item.origin.map { ($0.place, frame.mediaTime) } } },
            uniquingKeysWith: { first, _ in first }
        )
        #expect(entries.map { $0.1 } == [1.5, 2, 0.5, 0.5])
        #expect(drawn == ["storyline[1]": 2, "storyline[1].connected[0]": 0.5, "storyline[1].connected[1]": 0.5])
        #expect(entries.filter { drawn[$0.0] != nil }.allSatisfy { drawn[$0.0] == $0.1 })
    }

    @Test("every entry gives its instant and the clock of the times it writes, a storyline, a connected and a sequence clip's")
    func reportsInstantsAndClocks() throws {
        // Given
        let value = try Fixture.json(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [
                { "media": "/abs/short.mp4", "in": 1, "out": 3 },
                { "media": "/abs/leak.mov", "in": 0.5, "out": 1.5, "speed": 2,
                  "connected": [ { "at": [1, 1.4], "title": "a", "style": "title" }, { "title": "b", "style": "title" } ] } ],
              "clips": [ { "at": [1, 2], "title": "c", "style": "title" }, { "title": "d", "style": "title" } ] }
            """#)
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(value), hashes: FileHashTable())

        // When
        let report = try sut.report(of: value)
        let resolvedReport = sut.report(of: resolved)

        // Then
        let clock = { (clip: String?, origin: Double, speed: Double) -> JSONValue in
            .object(JSONObject(members: [
                JSONMember(key: "clip", value: clip.map(JSONValue.string) ?? .null),
                JSONMember(key: "origin", value: .number(origin)),
                JSONMember(key: "speed", value: .number(speed))
            ]))
        }
        #expect(entries(of: report).map { $0["instant"] } == [0, 2, 2.25, 2, 1, 0].map(JSONValue.number))
        #expect(entries(of: report).map { $0["clock"] } == [
            clock("storyline[0]", -1, 1),
            clock("storyline[1]", 1.75, 2),
            clock("storyline[1]", 1.75, 2),
            clock("storyline[1]", 1.75, 2),
            clock(nil, 0, 1),
            clock(nil, 0, 1)
        ])
        #expect(entries(of: resolvedReport).allSatisfy { $0["instant"] == .null && $0["clock"] == clock(nil, 0, 1) })
    }

    @Test("every entry gives the space its coordinates are written in and the space of its crop and mask, through every kind of parent")
    func reportsSpaces() throws {
        // Given
        let value = try Fixture.json(##"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [
                { "id": "shot", "media": "/abs/short.mp4", "in": 0, "out": 2,
                  "connected": [ { "id": "pip", "media": "/abs/leak.mov", "parent": "shot", "position": [100, 100] } ] },
                { "id": "black", "solid": "#000000", "duration": 2 } ],
              "clips": [
                { "id": "ring", "at": [0, 2], "shape": "rect", "stroke": { "width": 8 }, "area": [10, 10, 50, 50], "parent": "pip" },
                { "id": "label", "at": [0, 2], "title": "a", "style": "title", "parent": "ring", "position": [10, 10] },
                { "at": [0, 2], "shape": "rect", "stroke": { "width": 8 }, "width": 40, "height": 20, "parent": "label", "position": [0, 0] },
                { "id": "card", "at": [0, 2], "title": "b", "style": "title", "parent": "pip", "cornerPin": [[0, 0], [100, 0], [100, 50], [0, 50]] },
                { "at": [0, 2], "title": "c", "style": "title", "parent": "card", "position": [5, 5] },
                { "at": [2, 4], "title": "d", "style": "title", "parent": "black", "position": [5, 5] },
                { "at": [0, 2], "title": "e", "style": "title" },
                { "at": 0, "media": "/abs/ding.wav" } ] }
            """##)
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(value), hashes: FileHashTable())

        // When
        let report = try sut.report(of: value)
        let resolvedReport = sut.report(of: resolved)

        // Then
        let space = { (kind: String, clip: String?) -> JSONValue in
            .object(JSONObject(members: [
                JSONMember(key: "kind", value: .string(kind)),
                JSONMember(key: "clip", value: clip.map(JSONValue.string) ?? .null)
            ]))
        }
        let shot = space("media", "storyline[0]#shot")
        let pip = space("media", "storyline[0]#shot.connected[0]#pip")
        let label = space("box", "clips[1]#label")
        let output = space("output", nil)
        let expected: [[JSONValue?]] = [
            [output, shot],
            [output, output],
            [shot, pip],
            [pip, pip],
            [pip, label],
            [label, space("box", "clips[2]")],
            [pip, space("box", "clips[3]#card")],
            [pip, space("box", "clips[4]")],
            [output, space("box", "clips[5]")],
            [output, space("box", "clips[6]")],
            [.null, .null]
        ]
        #expect(entries(of: report).map { [$0["space"], $0["ownSpace"]] } == expected)
        #expect(entries(of: resolvedReport).map { [$0["space"], $0["ownSpace"]] } == Array(expected.dropLast()))
    }

    @Test("every entry gives the clip whose video a track on it follows, its own or its parent's, and none where there is no video to follow")
    func reportsTrackedClips() throws {
        // Given
        let value = try Fixture.json(##"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [
                { "id": "shot", "media": "/abs/short.mp4", "in": 0, "out": 2,
                  "connected": [ { "id": "pip", "media": "/abs/leak.mov", "parent": "shot", "position": [100, 100] } ] },
                { "id": "black", "solid": "#000000", "duration": 2 } ],
              "clips": [
                { "id": "ring", "at": [0, 2], "shape": "rect", "stroke": { "width": 8 }, "area": [10, 10, 50, 50], "parent": "pip" },
                { "id": "label", "at": [0, 2], "title": "a", "style": "title", "parent": "ring", "position": [10, 10] },
                { "id": "card", "at": [0, 2], "title": "b", "style": "title", "parent": "pip", "cornerPin": [[0, 0], [100, 0], [100, 50], [0, 50]] },
                { "at": [0, 2], "title": "c", "style": "title", "parent": "card", "position": [5, 5] },
                { "at": [2, 4], "title": "d", "style": "title", "parent": "black", "position": [5, 5] },
                { "at": [0, 2], "title": "e", "style": "title" },
                { "at": 0, "media": "/abs/ding.wav" } ] }
            """##)
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(value), hashes: FileHashTable())

        // When
        let report = try sut.report(of: value)
        let resolvedReport = sut.report(of: resolved)

        // Then
        let shot = JSONValue.string("storyline[0]#shot")
        let pip = JSONValue.string("storyline[0]#shot.connected[0]#pip")
        let expected: [JSONValue?] = [shot, nil, pip, pip, nil, pip, nil, nil, nil, nil]
        #expect(entries(of: report).map { $0["tracked"]?.objectValue?["clip"] } == expected)
        #expect(entries(of: resolvedReport).allSatisfy { $0["tracked"] == .null })
    }

    @Test("tracked gives the first and the last frame a clip's time map shows over its window, speed, timeRemap and loop applied")
    func reportsTrackedFrames() throws {
        // Given
        let value = try Fixture.json(timeMapped)

        // When
        let report = try sut.report(of: value)

        // Then
        let tracked = { (clip: String, first: Double, last: Double) -> JSONValue in
            .object(JSONObject(members: [
                JSONMember(key: "clip", value: .string(clip)),
                JSONMember(key: "first", value: .number(first)),
                JSONMember(key: "last", value: .number(last))
            ]))
        }
        #expect(entries(of: report).map { $0["tracked"] } == [
            tracked("storyline[0]", 0.5, 1.5),
            tracked("storyline[1]", 1, 3),
            tracked("storyline[1].connected[0]", 0.5, 1),
            tracked("storyline[1].connected[1]", 0.5, 1)
        ])
    }

    // MARK: - Private
    // Every entry of a report's machine output, storyline first.
    private func entries(of report: TimelineReport) -> [JSONObject] {
        let output = report.machineOutput.objectValue
        return ["storyline", "clips"].flatMap { output?[$0]?.arrayValue?.compactMap(\.objectValue) ?? [] }
    }

    // A report's machine output without `instant`, `clock` and `tracked`, which a resolved document gives as it keeps
    // them, every instant in sequence time and every track as resolve fitted it.
    private func withoutClocks(_ value: JSONValue) -> JSONValue {
        switch value {
        case let .object(object):
            .object(JSONObject(members: object.members.filter { !["instant", "clock", "tracked"].contains($0.key) }.map { member in
                JSONMember(key: member.key, value: withoutClocks(member.value))
            }))

        case let .array(elements):
            .array(elements.map(withoutClocks))

        default:
            value
        }
    }

    // `/abs/leak.mov` has frames every half second to 1.5, and `/abs/short.mp4` every second to 3. The first clip plays
    // from media second 0.5 at speed 2 over [0, 0.5), and the second is remapped from 3 down to 1 over [0.5, 2.5),
    // with a looping clip over [1, 2.5) and one over [1, 1.5) from media second 0.5.
    private var timeMapped: String {
        #"""
        { "kind": "sequence", "format": { "size": [1080, 1920] },
          "storyline": [
            { "media": "/abs/leak.mov", "in": 0.5, "out": 1.5, "speed": 2 },
            { "media": "/abs/short.mp4", "in": 0, "out": 2, "keyframes": [ { "at": 0, "timeRemap": 3 }, { "at": 2, "timeRemap": 1 } ],
              "connected": [ { "media": "/abs/leak.mov", "at": [0.5, 2], "in": 0.5, "out": 1.5, "loop": true },
                             { "media": "/abs/leak.mov", "at": [0.5, 1], "in": 0.5 } ] } ] }
        """#
    }

    // A box on [100, 100, 200, 40], tracked from the frame its instant shows, and a title over the whole sequence.
    private var tracked: String {
        let track = tracker.data(Quad(Rectangle(x: 100, y: 100, width: 200, height: 40)), in: "/abs/screen.mp4", atMediaTime: 1.5)
        return #"""
            { "kind": "sequence", "theme": { "baseWidth": 1206 },
              "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 1, "out": 3,
                "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "area": [100, 100, 200, 40], "parent": "screen", "at": [1.5, 3], "track": \#(track) } ] } ],
              "clips": [ { "at": [0, 2], "title": "Pay now", "style": "title" } ] }
            """#
    }
}
