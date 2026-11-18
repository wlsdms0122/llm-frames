//
//  SequencePlannerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// `/abs/screen.mp4` is 1206 wide, the base theme's `baseWidth`, so its lengths are the theme's points, and "Total" is
// on every frame. `/abs/short.mp4` is 1080 wide and shows "Send". The fake shaper sets each character half the size
// wide and a space a quarter.
@Suite("SequencePlanner Tests")
struct SequencePlannerTests {
    // MARK: - Property
    private let sut = Fixture.sequencePlanner

    // MARK: - Initializer
    // MARK: - Test
    @Test("the format defaults to the size of the first video on the storyline, rounded to even numbers")
    func defaultsFormatToFirstVideo() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/card.png", "duration": 1 }, { "media": "/abs/halfway.mp4" } ] }
            """#)

        // Then
        #expect(plan.format == FormatPlan(
            size: Size(width: 1080, height: 1920),
            conform: .fit,
            background: Color(written: "#000000"),
            fps: 25,
            duration: 5
        ))
    }

    @Test(
        "without video the format defaults to the size of the first storyline clip, a compound clip's being its document's",
        arguments: [
            (#"{ "media": "/abs/card.png", "duration": 1 }"#, Size(width: 1080, height: 1350)),
            (##"{ "media": { "kind": "sequence", "format": { "size": [640, 480] }, "storyline": [ { "solid": "#000000", "duration": 1 } ] } }"##, Size(width: 640, height: 480))
        ]
    )
    func defaultsFormatToFirstClip(
        clip: String,
        size: Size
    ) throws {
        // When
        let plan = try plan(#"{ "kind": "sequence", "storyline": [ \#(clip) ] }"#)

        // Then
        #expect(plan.format.size == size)
    }

    @Test("a written size, conform, fps and background are kept")
    func readsWrittenFormat() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence",
              "format": { "size": [1081, 1920], "fps": 60, "background": "accent", "conform": "fill" },
              "storyline": [ { "media": "/abs/run.mp4" } ] }
            """#)

        // Then
        #expect(plan.format == FormatPlan(
            size: Size(width: 1081, height: 1920),
            conform: .fill,
            background: Color(written: "#FFFFFF"),
            fps: 60,
            duration: 30
        ))
    }

    @Test("a format without a size on a storyline of no video that starts with a solid stops")
    func refusesFormatWithoutSize() throws {
        // Given
        let document = ##"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 1 }, { "media": "/abs/card.png", "duration": 1 } ] }
            """##

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == #"top level (sequence): the storyline has no video and its first clip is a solid, which has no size, so the format needs "size""#)
    }

    @Test("a storyline crop is found in its media and grows by its padding, in that picture's pixels")
    func findsStorylineCrop() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "crop": { "text": "Total", "padding": 40 } }, { "media": "/abs/short.mp4", "crop": [0, 0, 540, 960] } ] }
            """#)

        // Then
        guard case let .value(crop) = plan.storyline[0].crop else {
            Issue.record("the crop was not found")
            return
        }
        #expect(crop.rectangle == Fixture.total.grown(by: 40))
        #expect(crop.target == Fixture.total)
        #expect(plan.storyline[1].crop == .value(FoundArea(
            rectangle: Rectangle(x: 0, y: 0, width: 540, height: 960),
            target: Rectangle(x: 0, y: 0, width: 540, height: 960),
            mediaTime: 0,
            lines: []
        )))
    }

    @Test("a text area is found in its storyline parent's picture and grows by its padding, in that picture's pixels")
    func findsParentedArea() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "id": "short", "media": "/abs/short.mp4", "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Send", "padding": 14 }, "parent": "short" } ] } ] }
            """#)

        // Then
        guard case let .value(area) = plan.clips[0].area else {
            Issue.record("the area was not found")
            return
        }
        #expect(area.rectangle == Fixture.send.grown(by: 14))
        #expect(area.lines.map(\.text) == ["Send"])
    }

    @Test("a sequence clip's area is in output pixels")
    func keepsSequenceArea() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ],
              "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "area": [10, 20, 30, 40], "at": [0, 1] } ] }
            """#)

        // Then
        #expect(plan.clips[0].area == .value(FoundArea(
            rectangle: Rectangle(x: 10, y: 20, width: 30, height: 40),
            target: Rectangle(x: 10, y: 20, width: 30, height: 40),
            mediaTime: 0,
            lines: []
        )))
    }

    @Test("a parented position given by a text area is the point it names, padding included")
    func findsAreaPosition() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "title": "a", "style": "title", "parent": "screen", "anchor": "right", "position": { "area": { "text": "Total", "padding": 14 }, "point": "left" } },
                { "title": "b", "style": "title", "position": [10, 20] } ] } ] }
            """#)

        // Then
        #expect(plan.clips[0].position == .value(Point(x: 86, y: 120)))
        #expect(plan.clips[1].position == .value(Point(x: 10, y: 20)))
    }

    @Test(
        "a text area or a position given by one on a clip without a parent stops, naming where it is written",
        arguments: [
            (#"{ "title": "a", "style": "title", "position": { "area": { "text": "Total" }, "point": "left" } }"#, "storyline[0].connected[0].position", "title"),
            (#"{ "title": "a", "style": "title", "keyframes": [ { "at": 0, "position": [0, 0] }, { "at": 1, "position": { "area": { "text": "Total" }, "point": "left" } } ] }"#, "storyline[0].connected[0].keyframes[1].position", "title"),
            (#"{ "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Total" } }"#, "storyline[0].connected[0].area", "rect"),
            (#"{ "shape": "rect", "stroke": { "width": 8 }, "keyframes": [ { "at": 0, "area": [0, 0, 10, 10] }, { "at": 1, "area": { "text": "Total" } } ] }"#, "storyline[0].connected[0].keyframes[1].area", "rect")
        ]
    )
    func refusesTextAreaWithoutParent(
        clip: String,
        place: String,
        kind: String
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "connected": [ \#(clip) ] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == #"\#(place) (\#(kind)): a text area is searched in the media of the clip's parent, and this clip's coordinates are output pixels"#)
    }

    @Test("a sequence clip without a parent takes a position given by the point of a numeric area, in output pixels")
    func findsNumericAreaPosition() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [
                { "title": "a", "style": "title", "at": [0, 1], "position": { "area": [10, 20, 100, 40], "point": "right" } } ] }
            """#)

        // Then
        #expect(plan.clips[0].position == .value(Point(x: 110, y: 40)))
    }

    @Test("a sequence clip parented to a storyline clip finds its text area in that clip's picture")
    func findsSequenceClipTextArea() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4" } ], "clips": [
                { "shape": "rect", "stroke": { "width": 8 }, "at": [0, 1], "parent": "screen", "area": { "text": "Total" } } ] }
            """#)

        // Then
        guard case let .value(area) = plan.clips[0].area else {
            Issue.record("the area was not found")
            return
        }
        #expect(area.target == Fixture.total)
    }

    @Test("a text area under a media clip parent is found in that clip's media at the media time its clock gives")
    func findsTextAreaInMediaClipParent() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
                { "id": "screen", "media": "/abs/screen.mp4", "in": 1.5, "at": [0, 2], "width": 300 },
                { "shape": "rect", "stroke": { "width": 8 }, "at": [0, 2], "parent": "screen", "area": { "text": "Total" } } ] }
            """#)

        // Then
        guard case let .value(area) = plan.clips[1].area else {
            Issue.record("the area was not found")
            return
        }
        #expect(area.target == Fixture.total)
        #expect(area.mediaTime == 1.5)
    }

    @Test("a text area under a media clip parent with a speed is searched at the media time its time map gives")
    func findsTextAreaThroughTimeMap() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
                { "id": "screen", "media": "/abs/screen.mp4", "in": 1, "speed": 2, "at": [0, 2], "width": 300 },
                { "shape": "rect", "stroke": { "width": 8 }, "at": [0.5, 2], "parent": "screen", "area": { "text": "Total" } } ] }
            """#)

        // Then
        guard case let .value(area) = plan.clips[1].area else {
            Issue.record("the area was not found")
            return
        }
        // Sequence second 0.5 is clip second 0.5 of the parent, which plays from media second 1 at twice the speed.
        #expect(area.mediaTime == 2)
    }

    @Test(
        "a text form on or under a picture that is drawn, not read, stops: a compound clip and a shape under a compound clip",
        arguments: [
            #"""
            { "kind": "sequence", "storyline": [ { "id": "nest", "media": { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ] },
              "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "parent": "nest", "area": { "text": "Total" } } ] } ] }
            """#,
            #"""
            { "kind": "sequence", "storyline": [ { "media": { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ] },
              "crop": { "text": "Total" } } ] }
            """#,
            #"""
            { "kind": "sequence", "storyline": [ { "id": "nest", "media": { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ] },
              "connected": [ { "id": "box", "shape": "rect", "stroke": { "width": 8 }, "parent": "nest", "area": [0, 0, 10, 10] },
                             { "title": "a", "style": "title", "parent": "box", "position": { "area": { "text": "Total" }, "point": "left" } } ] } ] }
            """#
        ]
    )
    func refusesTextInDrawnPicture(document: String) throws {
        // When, Then
        let error = #expect(throws: AreaError.self) { try plan(document) }
        #expect(error?.description.contains("drawn, not read") == true)
    }

    @Test("a text area under a title parent stops, since its text box has no picture to read")
    func refusesTextAreaInSpace() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [
                { "id": "parent", "title": "a", "style": "title", "at": [0, 1], "position": [100, 100] },
                { "shape": "rect", "stroke": { "width": 8 }, "at": [0, 1], "parent": "parent", "area": { "text": "Total" } } ] }
            """#

        // When, Then
        let error = #expect(throws: AreaError.self) { try plan(document) }
        #expect(error?.description == #"clips[1].area (rect): the parent "parent" is a title, whose text box has no picture to read, so it takes no text area"#)
    }

    @Test(
        "a text area under a shape or adjustment without a parent stops, since their coordinates are output pixels",
        arguments: [
            #"{ "id": "parent", "shape": "rect", "stroke": { "width": 8 }, "at": [0, 1], "area": [0, 0, 100, 100] }"#,
            #"{ "id": "parent", "adjust": "frames/vivid", "at": [0, 1], "area": [0, 0, 100, 100] }"#
        ]
    )
    func refusesTextAreaInOutput(parent: String) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [
                \#(parent), { "shape": "rect", "stroke": { "width": 8 }, "at": [0, 1], "parent": "parent", "area": { "text": "Total" } } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error == .textAreaInOutputPixels(
            place: Place.root.appending(key: "clips").appending(index: 1).appending(key: "area"),
            kind: .clip(.shape("rect"))
        ))
    }

    @Test("a text area under a solid stops, since a solid's space is output pixels")
    func refusesTextAreaUnderSolid() throws {
        // Given
        let document = ##"""
            { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "id": "back", "solid": "#000000", "duration": 1,
              "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "parent": "back", "area": { "text": "Total" } } ] } ] }
            """##

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error == .textAreaInOutputPixels(
            place: Place.root.appending(key: "storyline").appending(index: 0, id: "back").appending(key: "connected")
                .appending(index: 0).appending(key: "area"),
            kind: .clip(.shape("rect"))
        ))
    }

    @Test("a title parented to a box placed by a text area takes a position at a point of that text in the box's parent")
    func findsPositionUnderShape() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "id": "box", "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total" } },
                { "title": "a", "style": "title", "parent": "box", "anchor": "left", "position": { "area": { "text": "Total", "padding": 14 }, "point": "right" } } ] } ] }
            """#)

        // Then
        #expect(plan.clips[1].position == .value(Point(x: 314, y: 120)))
    }

    @Test(
        "a numeric area under a shape or adjustment parent is cut at the edges of the media they are written in",
        arguments: [
            #"{ "id": "parent", "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 100, 100] }"#,
            #"{ "id": "parent", "adjust": "mine/grade", "parent": "screen", "area": [0, 0, 100, 100] }"#
        ]
    )
    func cutsAreaUnderShape(parent: String) throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                \#(parent), { "shape": "rect", "stroke": { "width": 8 }, "parent": "parent", "area": [-50, -50, 5000, 5000] } ] } ] }
            """#)

        // Then
        guard case let .value(area) = plan.clips[1].area else {
            Issue.record("the area was not found")
            return
        }
        #expect(area.rectangle == Rectangle(x: 0, y: 0, width: 1206, height: 2622))
    }

    @Test("a numeric area under a title parent is kept whole, since a space has no edges to cut it at")
    func keepsAreaInSpace() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [
                { "id": "name", "title": "a", "style": "title", "at": [0, 1], "position": [100, 100] },
                { "shape": "rect", "stroke": { "width": 8 }, "at": [0, 1], "parent": "name", "area": [-50, -50, 5000, 5000] } ] }
            """#)

        // Then
        guard case let .value(area) = plan.clips[1].area else {
            Issue.record("the area was not found")
            return
        }
        #expect(area.rectangle == Rectangle(x: -50, y: -50, width: 5000, height: 5000))
    }

    @Test("a media clip's crop is found in its own media, at its own media time")
    func findsMediaClipCrop() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "connected": [ { "media": "/abs/screen.mp4", "in": 1.5, "at": 0, "crop": { "text": "Total", "padding": 40 } } ] } ] }
            """#)

        // Then
        guard case let .value(crop) = plan.clips[0].crop else {
            Issue.record("the crop was not found")
            return
        }
        #expect(crop.rectangle == Fixture.total.grown(by: 40))
        #expect(crop.mediaTime == 1.5)
    }

    @Test("a tracked clip keeps what was followed, and its window narrows to the frames followed")
    func tracks() throws {
        // Given
        let sut = planner(followed: 0...1.9)

        // When
        let plan = try sut.plan(Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 1, "out": 3,
              "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total" }, "at": [1.5, 2.5], "track": { "text": "Total" } } ] } ] }
            """#)))

        // Then
        #expect(plan.storyline[0].track == nil)
        #expect(plan.clips[0].track?.track.target == Fixture.total)
        #expect(plan.time.clips[0].visible == TimeRange(start: 0.5, end: 1))
    }

    @Test("keyframes that all fall outside the window tracking narrowed stop, on the narrowed window")
    func refusesKeyframesOutsideNarrowedWindow() throws {
        // Given
        let sut = planner(followed: 0...1.9)
        let time = try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 1, "out": 3,
              "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total" }, "at": [1.5, 2.5], "track": { "text": "Total" },
                               "keyframes": [ { "at": 2.2, "opacity": 0 }, { "at": 2.4, "opacity": 1 } ] } ] } ] }
            """#))

        // When, Then
        #expect(throws: Never.self) { try Fixture.sequencePlanner.plan(time) }
        let error = #expect(throws: ResolveError.self) { try sut.plan(time) }
        #expect(error?.description == #"storyline[0]#screen.connected[0].keyframes (rect): every keyframe of "opacity" lies outside [0.5, 1), so only one of its values would ever show"#)
    }

    @Test(
        "a property whose keyframes all lie outside the range its clip shows in stops",
        arguments: [
            (
                #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "keyframes": [ { "at": 9, "crop": { "scale": 1 } }, { "at": 10, "crop": { "scale": 2 } } ] } ] }"#,
                #"storyline[0].keyframes (video): every keyframe of "crop" lies outside [0, 6), so only one of its values would ever show"#
            ),
            (
                #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "connected": [ { "at": [2, 4], "title": "a", "style": "subtitle", "keyframes": [ { "at": 6, "opacity": 0 }, { "at": 7, "opacity": 1 } ] } ] } ] }"#,
                #"storyline[0].connected[0].keyframes (title): every keyframe of "opacity" lies outside [2, 4), so only one of its values would ever show"#
            )
        ]
    )
    func refusesKeyframesOutsideRange(
        document: String,
        message: String
    ) throws {
        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == message)
    }

    @Test(
        "a title wraps at its width, by default the output width less the placement padding on each side",
        arguments: [("", 2), (#", "width": 1200"#, 1)]
    )
    func wrapsTitle(
        width: String,
        lineCount: Int
    ) throws {
        // Given
        let word = String(repeating: "a", count: 30)

        // When
        let plan = try plan(#"""
            { "kind": "sequence", "theme": { "styles": { "caption": { "size": 60 } } }, "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ { "title": "\#(word) \#(word)", "style": "caption", "placement": "top", "at": [0, 1]\#(width) } ] }
            """#)

        // Then
        #expect(plan.clips[0].title?.lineCount == lineCount)
    }

    @Test("a title is set at the length scale of the output")
    func scalesTitle() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [3840, 5244] }, "theme": { "styles": { "caption": { "size": 38, "lineHeight": 64 } } },
              "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ { "title": "a", "style": "caption", "placement": "top", "at": [0, 1] } ] }
            """#)

        // Then
        #expect(plan.clips[0].title?.size == Size(width: 38, height: 128))
        #expect(plan.clips[0].title?.runs.first?.size == 76)
    }

    @Test("a title naming a style the theme does not hold stops at its style, listing the styles the theme holds")
    func refusesUnknownTitleStyle() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ { "title": "Hi", "style": "nope", "position": [400, 225], "at": [0, 1] } ] }
            """#

        // When, Then
        let error = #expect(throws: ThemeError.self) { try plan(document) }
        #expect(error?.description == #"clips[0].style (title): style "nope" is not in styles, "#
            + #"which hold "subtitle", "title""#)
    }

    @Test(
        "a title naming a style the base theme no longer holds stops",
        arguments: ["banner", "bannerHead", "heading", "headline"]
    )
    func refusesRemovedTitleStyle(_ style: String) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ { "title": "Hi", "style": "\#(style)", "position": [400, 225], "at": [0, 1] } ] }
            """#

        // When, Then
        let error = #expect(throws: ThemeError.self) { try plan(document) }
        #expect(error?.description == #"clips[0].style (title): style "\#(style)" is not in styles, "#
            + #"which hold "subtitle", "title""#)
    }

    @Test("a title takes a style its document's theme adds")
    func findsDocumentThemeStyle() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "theme": { "styles": { "callout": { "size": 40 } } },
              "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ { "title": "a", "style": "callout", "position": [400, 225], "at": [0, 1] } ] }
            """#)

        // Then
        #expect(plan.clips[0].title?.runs.first?.size == 40 * (1206 / 1920.0))
    }

    @Test("a nested document is planned on its own, with its own format, for a storyline clip and another clip")
    func plansNested() throws {
        // Given
        let nested = ##"{ "kind": "sequence", "format": { "size": [640, 480] }, "storyline": [ { "solid": "#000000", "duration": 1 } ] }"##

        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "connected": [ { "media": \#(nested), "at": 0 } ] }, { "media": \#(nested) } ] }
            """#)

        // Then
        #expect(plan.format.size == Size(width: 1080, height: 1920))
        #expect(plan.clips[0].nested?.format.size == Size(width: 640, height: 480))
        #expect(plan.storyline[1].nested?.format.size == Size(width: 640, height: 480))
        #expect(plan.storyline[0].nested == nil)
    }

    // MARK: - Private
    @Test("how each clip is drawn is planned, with keyframes in sequence time and filter lengths scaled")
    func plansAppearance() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [2160, 3840] },
              "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "filter": "mine/grade", "connected": [
                { "title": "a", "style": "title", "placement": "top", "at": [3, 5], "blend": "screen", "scale": 2,
                  "keyframes": [ { "at": 3, "opacity": 0 }, { "at": 4, "opacity": 1, "ease": "ease-in" } ] } ] } ],
              "clips": [
                { "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1] },
                { "adjust": ["mine/grade", "none"], "area": [0, 0, 10, 10], "at": [0, 1] } ] }
            """#

        // When
        let plan = try plan(document)

        // Then
        let graded: [FilterOperation] = [.saturation(amount: 1.25), .blur(radius: 4 * MergedTheme.base.lengthScale(at: 2160))]
        let title = plan.clips[0].appearance
        #expect(plan.storyline[0].filter == graded)
        #expect(title.opacity == .keyframes([
            TimedValue(index: 0, at: 1, value: 0, ease: .linear),
            TimedValue(index: 1, at: 2, value: 1, ease: .easeIn)
        ]))
        #expect(title.scale == .value(2))
        #expect(title.rotation == .value(0))
        #expect(title.blend == "screen")
        #expect(title.shape == nil)
        #expect(plan.clips[1].appearance.blend == "normal")
        #expect(plan.clips[1].appearance.shape == ShapeAppearance(
            kind: .rect,
            geometry: .area(outset: 0, anchor: nil),
            radius: .value(0),
            trim: .value(.whole),
            fill: nil,
            stroke: PathStroke(
                width: 8 * MergedTheme.base.lengthScale(at: 2160),
                color: MergedTheme.base.color("accent"),
                join: .round,
                cap: .butt,
                start: .none,
                end: .none
            ),
            shadow: nil
        ))
        #expect(plan.clips[2].appearance.filter == graded)
    }

    @Test("a storyline clip that writes none of its transform has the frame as its box and fills it exactly")
    func fillsFrameByDefault() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "media": "/abs/run.mp4" } ] }
            """#)

        // Then
        #expect(plan.storyline[0].appearance == StorylineAppearance(
            box: ClipBox(size: Size(width: 1080, height: 1920), position: .value(Point(x: 0, y: 0)), anchor: Point(x: 540, y: 960)),
            opacity: .value(1),
            scale: .value(1),
            rotation: .value(0),
            blend: "normal",
            radius: 0,
            border: nil,
            shadow: nil
        ))
    }

    @Test("a storyline clip's anchor is named on the frame, its keyframes move to sequence time, its radius is a theme length, and its border and shadow are the theme's")
    func plansStorylineTransform() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "anchor": "top-left", "rotation": 90, "blend": "screen",
                               "radius": 12, "border": true, "shadow": true,
                               "keyframes": [ { "at": 3, "position": [0, 0], "scale": 1 }, { "at": 5, "position": [540, 960], "scale": 0.5 } ] } ] }
            """#

        // When
        let plan = try plan(document)

        // Then
        let theme = MergedTheme.base
        let scale = theme.lengthScale(at: 1080)
        let appearance = plan.storyline[0].appearance
        #expect(appearance.box == ClipBox(
            size: Size(width: 1080, height: 1920),
            position: .keyframes([
                TimedValue(index: 0, at: 1, value: Point(x: 0, y: 0), ease: .linear),
                TimedValue(index: 1, at: 3, value: Point(x: 540, y: 960), ease: .linear)
            ]),
            anchor: Point(x: 0, y: 0)
        ))
        #expect(appearance.scale == .keyframes([
            TimedValue(index: 0, at: 1, value: 1, ease: .linear),
            TimedValue(index: 1, at: 3, value: 0.5, ease: .linear)
        ]))
        #expect(appearance.rotation == .value(90))
        #expect(appearance.opacity == .value(1))
        #expect(appearance.blend == "screen")
        #expect(appearance.radius == 12 * scale)
        #expect(appearance.border == MediaBorder(width: theme.borderWidth * scale, color: theme.borderColor))
        #expect(appearance.shadow == DropShadow(
            radius: theme.shadowRadius * scale,
            offset: Point(x: theme.shadowOffset.x * scale, y: theme.shadowOffset.y * scale),
            color: theme.shadowColor
        ))
    }

    @Test("a storyline clip has no parent, so a position written with text stops")
    func refusesStorylineTextPosition() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "position": { "area": { "text": "Total" }, "point": "center" } } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error == .textAreaInOutputPixels(
            place: Place.root.appending(key: "storyline").appending(index: 0).appending(key: "position"),
            kind: .clip(.media(.video))
        ))
    }

    @Test("a filter naming a preset that is not there stops where it is written")
    func refusesUnknownFilter() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "filter": ["mine/grade", "mine/cold"] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error == .unknownPreset(place: Place.root.appending(key: "storyline").appending(index: 0).appending(key: "filter").appending(index: 1), kind: .clip(.media(.video)), presetKind: "filter", name: "mine/cold"))
    }

    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }

    private func planner(followed: ClosedRange<Double>) -> SequencePlanner {
        SequencePlanner(
            ocr: Fixture.ocr,
            tracker: TrackerTable(
                frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes],
                followed: ["/abs/screen.mp4": followed]
            ),
            shaper: Fixture.shaper,
            presets: Fixture.presets,
            library: Fixture.library
        )
    }
}
