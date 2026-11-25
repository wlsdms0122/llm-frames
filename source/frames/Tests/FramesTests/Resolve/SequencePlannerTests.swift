//
//  SequencePlannerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// `/abs/screen.mp4` is 1206 wide and `/abs/short.mp4` is 1080 wide. The base theme's lengths are for a frame 1920
// wide. The fake shaper sets each character half the size wide and a space a
// quarter.
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
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/card.png", "duration": 1 }, { "kind": "media", "media": "/abs/halfway.mp4" } ] }
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
            (#"{ "kind": "media", "media": "/abs/card.png", "duration": 1 }"#, Size(width: 1080, height: 1350)),
            (##"{ "kind": "media", "media": { "kind": "sequence", "format": { "size": [640, 480] }, "storyline": [ { "kind": "solid", "color": "#000000", "duration": 1 } ] } }"##, Size(width: 640, height: 480))
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
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }
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
            { "kind": "sequence", "storyline": [ { "kind": "solid", "color": "#000000", "duration": 1 }, { "kind": "media", "media": "/abs/card.png", "duration": 1 } ] }
            """##

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == #"top level (sequence): the storyline has no video and its first clip is a solid, which has no size, so the format needs "size""#)
    }

    @Test("a storyline crop is kept as written, in its picture's pixels")
    func findsStorylineCrop() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "crop": [60, 60, 280, 120] }, { "kind": "media", "media": "/abs/short.mp4", "crop": [0, 0, 540, 960] } ] }
            """#)

        // Then
        #expect(plan.storyline[0].crop == .value(Rectangle(x: 60, y: 60, width: 280, height: 120)))
        #expect(plan.storyline[1].crop == .value(Rectangle(x: 0, y: 0, width: 540, height: 960)))
    }

    @Test("a sequence clip's area is in output pixels")
    func keepsSequenceArea() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "area": [10, 20, 30, 40], "at": [0, 1] } ] }
            """#)

        // Then
        #expect(plan.clips[0].area == .value(.rectangle(Rectangle(x: 10, y: 20, width: 30, height: 40))))
    }

    @Test("a parented position given by an area is the point it names")
    func findsAreaPosition() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "connected": [
                { "kind": "title", "text": "a", "style": "title", "parent": "screen", "anchor": "right", "position": { "area": [86, 86, 228, 68], "point": "left" } },
                { "kind": "title", "text": "b", "style": "title", "position": [10, 20] } ] } ] }
            """#)

        // Then
        #expect(plan.clips[0].position == .value(.point(Point(x: 86, y: 120))))
        #expect(plan.clips[1].position == .value(.point(Point(x: 10, y: 20))))
    }

    @Test("a sequence clip without a parent takes a position given by the point of a numeric area, in output pixels")
    func findsNumericAreaPosition() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ], "clips": [
                { "kind": "title", "text": "a", "style": "title", "at": [0, 1], "position": { "area": [10, 20, 100, 40], "point": "right" } } ] }
            """#)

        // Then
        #expect(plan.clips[0].position == .value(.point(Point(x: 110, y: 40))))
    }

    @Test(
        "a numeric area under a shape or adjustment parent keeps what is written past the edges of the media it is in",
        arguments: [
            #"{ "id": "parent", "kind": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 100, 100] }"#,
            #"{ "id": "parent", "kind": "adjustment", "adjust": "mine/grade", "parent": "screen", "mask": { "kind": "rect", "area": [0, 0, 100, 100] } }"#
        ]
    )
    func keepsAreaUnderShape(parent: String) throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "connected": [
                \#(parent), { "kind": "rect", "stroke": { "width": 8 }, "parent": "parent", "area": [-50, -50, 5000, 5000] } ] } ] }
            """#)

        // Then
        guard case let .value(area) = plan.clips[1].area else {
            Issue.record("the area was not found")
            return
        }
        #expect(area.rectangle == Rectangle(x: -50, y: -50, width: 5000, height: 5000))
    }

    @Test("a numeric area under a title parent keeps what is written")
    func keepsAreaInSpace() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ], "clips": [
                { "id": "name", "kind": "title", "text": "a", "style": "title", "at": [0, 1], "position": [100, 100] },
                { "kind": "rect", "stroke": { "width": 8 }, "at": [0, 1], "parent": "name", "area": [-50, -50, 5000, 5000] } ] }
            """#)

        // Then
        guard case let .value(area) = plan.clips[1].area else {
            Issue.record("the area was not found")
            return
        }
        #expect(area.rectangle == Rectangle(x: -50, y: -50, width: 5000, height: 5000))
    }

    @Test("a tracked clip keeps what was followed, and its window narrows to the frames followed")
    func tracks() throws {
        // Given
        let track = data(followed: 0...1.9)

        // When
        let plan = try sut.plan(Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "in": 1, "out": 3,
              "connected": [ { "kind": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [100, 100, 200, 40], "at": [1.5, 2.5], "track": \#(track) } ] } ] }
            """#)))

        // Then
        #expect(plan.storyline[0].track == nil)
        #expect(plan.clips[0].track?.track.target == Quad(Rectangle(x: 100, y: 100, width: 200, height: 40)))
        #expect(plan.time.clips[0].visible == TimeRange(start: 0.5, end: 1))
    }

    @Test("keyframes that all fall outside the window tracking narrowed stop, on the narrowed window")
    func refusesKeyframesOutsideNarrowedWindow() throws {
        // Given
        let time = { (track: String) in
            try Fixture.planner.plan(document: Fixture.json(#"""
                { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "in": 1, "out": 3,
                  "connected": [ { "kind": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [100, 100, 200, 40], "at": [1.5, 2.5], "track": \#(track),
                                   "keyframes": [ { "at": 2.2, "opacity": 0 }, { "at": 2.4, "opacity": 1 } ] } ] } ] }
                """#))
        }

        // When, Then
        #expect(throws: Never.self) { try sut.plan(time(data())) }
        let error = #expect(throws: ResolveError.self) { try sut.plan(time(data(followed: 0...1.9))) }
        #expect(error?.description == #"storyline[0]#screen.connected[0].keyframes (rect): every keyframe of "opacity" lies outside [0.5, 1), so only one of its values would ever show"#)
    }

    @Test(
        "a leaf whose keyframes all lie outside the range its clip shows in stops",
        arguments: [
            (
                #"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 2, "out": 8, "keyframes": [ { "at": 9, "crop": { "scale": 1 } }, { "at": 10, "crop": { "scale": 2 } } ] } ] }"#,
                #"storyline[0].keyframes (video): every keyframe of "crop" lies outside [0, 6), so only one of its values would ever show"#
            ),
            (
                ##"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 2, "out": 8, "keyframes": [ { "at": 1, "shadow": { "radius": 2 } }, { "at": 2, "shadow": { "radius": 4 } }, { "at": 9, "shadow": { "color": "#FF0000" } }, { "at": 10, "shadow": { "color": "#000000" } } ] } ] }"##,
                #"storyline[0].keyframes (video): every keyframe of "shadow.color" lies outside [0, 6), so only one of its values would ever show"#
            ),
            (
                #"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [ { "at": [2, 4], "kind": "title", "text": "a", "style": "subtitle", "keyframes": [ { "at": 6, "opacity": 0 }, { "at": 7, "opacity": 1 } ] } ] } ] }"#,
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
        "a title wraps at its width, and without one runs on one line however long",
        arguments: [("", 1), (#", "width": 600"#, 2)]
    )
    func wrapsTitle(
        width: String,
        lineCount: Int
    ) throws {
        // Given
        let word = String(repeating: "a", count: 30)

        // When
        let plan = try plan(#"""
            { "kind": "sequence", "theme": { "styles": { "caption": { "size": 60 } } }, "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": "\#(word) \#(word)", "style": "caption", "placement": "top", "at": [0, 1]\#(width) } ] }
            """#)

        // Then
        #expect(plan.clips[0].title?.layout.lineCount == lineCount)
    }

    @Test("a title is set at the length scale of the output")
    func scalesTitle() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [3840, 5244] }, "theme": { "styles": { "caption": { "size": 38, "lineHeight": 64 } } },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": "a", "style": "caption", "placement": "top", "at": [0, 1] } ] }
            """#)

        // Then
        #expect(plan.clips[0].title?.layout.size == Size(width: 38, height: 76))
        #expect(plan.clips[0].title?.layout.runs.first?.size == 76)
    }

    @Test("a title's `character` merges over every run's style leaf by leaf and keeps what it does not write")
    func mergesCharacterOverRuns() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "colors": { "accent": "#FFD43B" },
                         "styles": { "caption": { "size": 40, "stroke": { "width": 4, "color": "#000000" } },
                                     "small": { "size": 20 } } },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": [ { "text": "a " }, { "text": "b", "style": "small" } ], "style": "caption",
                           "character": { "color": "accent", "stroke": { "width": 2 } },
                           "placement": "top", "at": [0, 1] } ] }
            """#)

        // Then
        let title = try #require(plan.clips[0].title)
        let characters = title.characters.map { $0.sampled(at: 0, as: LookStructureTable.character) }
        #expect(characters.map { $0["color"]?.color } == [Color(written: "#FFD43B"), Color(written: "#FFD43B")])
        #expect(title.layout.runs.map(\.size) == [40, 20])
        #expect(characters.map { $0["stroke"]?["width"]?.number } == [2, 2])
        #expect(characters.map { $0["stroke"]?["color"]?.color } == [Color(written: "#000000"), Color(written: "#FFFFFF")])
    }

    @Test("a title's `character` text orientation and composition merge over every run's style, and a run keeps its own where it writes neither")
    func mergesTextOrientationOverRuns() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "caption": { "size": 40, "textOrientation": "sideways" },
                                     "date": { "size": 40, "textCombineUpright": "all" } } },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": [ { "text": "NHK" }, { "text": "12", "style": "date" } ], "style": "caption",
                           "character": { "textOrientation": "upright" }, "placement": "top", "at": [0, 1] },
                         { "kind": "title", "text": [ { "text": "NHK" }, { "text": "12", "style": "date" } ], "style": "caption",
                           "placement": "top", "at": [0, 1] } ] }
            """#)

        // Then
        let characters = try plan.clips.map { clip in
            try #require(clip.title).characters.map { $0.sampled(at: 0, as: LookStructureTable.character) }
        }
        #expect(characters.map { $0.map { $0["textOrientation"]?.name } } == [["upright", "upright"], ["sideways", nil]])
        #expect(characters.map { $0.map { $0["textCombineUpright"]?.name } } == [[nil, "all"], [nil, "all"]])
    }

    @Test("a title's `paragraph` merges over its style's paragraph attributes, and its default line height follows `character`")
    func mergesParagraphOverStyle() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "caption": { "size": 40, "align": "left",
                                                  "background": { "color": "#000000", "padding": [10, 20] } } } },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": "a\nb", "style": "caption", "width": 200, "character": { "size": 80 },
                           "paragraph": { "align": "right", "background": { "radius": 6 } },
                           "placement": "top", "at": [0, 1] } ] }
            """#)

        // Then
        let title = try #require(plan.clips[0].title?.layout)
        #expect(title.background == TextBackground(
            color: Color(written: "#000000"),
            padding: Size(width: 20, height: 10),
            radius: 6
        ))
        #expect(title.runs.map { $0.glyphs.map(\.x) } == [[180], [180]])
        #expect(title.runs.map { $0.glyphs.map(\.y) } == [[74], [174]])
    }

    @Test("a title's `paragraph` direction lays its text out in that direction, its lines on the side it starts from")
    func readsParagraphDirection() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "caption": { "size": 40 } } },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": "ab", "style": "caption", "width": 200, "paragraph": { "direction": "rtl" },
                           "placement": "top", "at": [0, 1] },
                         { "kind": "title", "text": "ab", "style": "caption", "width": 200, "placement": "top", "at": [0, 1] } ] }
            """#)

        // Then
        let layouts = try plan.clips.map { try #require($0.title?.layout) }
        #expect(layouts.map(\.direction) == [.rtl, .ltr])
        #expect(layouts.map(\.align) == [.right, .left])
        #expect(layouts.map { $0.runs.map { $0.glyphs.map(\.x) } } == [[[160, 180]], [[0, 20]]])
    }

    @Test("a title's `paragraph` writing mode merges over its style's, which a title without one keeps")
    func readsParagraphWritingMode() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "caption": { "size": 40, "writingMode": "vertical-lr" } } },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": "ab", "style": "caption", "paragraph": { "writingMode": "vertical-rl" },
                           "placement": "top", "at": [0, 1] },
                         { "kind": "title", "text": "ab", "style": "caption", "placement": "top", "at": [0, 1] } ] }
            """#)

        // Then
        let layouts = try plan.clips.map { try #require($0.title?.layout) }
        #expect(layouts.map(\.writingMode) == [.verticalRightToLeft, .verticalLeftToRight])
    }

    @Test("a title's `character` stroke over a run style without one stops when it gives no width")
    func refusesCharacterStrokeWithoutWidth() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": "Hi", "style": "title", "character": { "stroke": { "color": "#FF0000" } },
                           "position": [400, 225], "at": [0, 1] } ] }
            """#

        // When, Then
        #expect(throws: ResolveError.self) { try plan(document) }
    }

    @Test("a title naming a style the theme does not hold stops at its style, listing the styles the theme holds")
    func refusesUnknownTitleStyle() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": "Hi", "style": "nope", "position": [400, 225], "at": [0, 1] } ] }
            """#

        // When, Then
        let error = #expect(throws: ThemeError.self) { try plan(document) }
        #expect(error?.description == #"clips[0].style (title): style "nope" is not in styles, "#
            + #"which hold "subtitle", "title""#)
    }

    @Test("a run naming a style the theme does not hold stops at the run's style")
    func refusesUnknownRunStyle() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "theme": { "styles": { "caption": { "size": 60 } } }, "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": [ { "text": "a" }, { "text": "b", "style": "nope" } ], "style": "caption", "placement": "top", "at": [0, 1] } ] }
            """#

        // When, Then
        let error = #expect(throws: ThemeError.self) { try plan(document) }
        #expect(error?.description == #"clips[0].text[1].style (title): style "nope" is not in styles, "#
            + #"which hold "caption", "subtitle", "title""#)
    }

    // The run in `big` is 80 high with an ascent of 64, the run in `caption` 60 high with a descent of 12, and the lines
    // lie the caption's 100 apart. The big style's line height, line limit and background would each change the box.
    @Test("a run takes its size from its own style and its paragraph attributes from the clip's style")
    func readsRunCharacterAttributesOnly() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "caption": { "size": 60, "lineHeight": 100 },
                                     "big": { "size": 80, "lineHeight": 400, "lines": 1, "align": "right",
                                              "background": { "color": "#000000", "padding": [10, 10], "radius": 4 } } } },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": [ { "text": "a\n", "style": "big" }, { "text": "b" } ], "style": "caption", "placement": "top", "at": [0, 1] } ] }
            """#)

        // Then
        let title = try #require(plan.clips[0].title?.layout)
        #expect(title.size == Size(width: 40, height: 176))
        #expect(title.background == nil)
        #expect(title.runs.map(\.size) == [80, 60])
        #expect(title.runs.map { $0.glyphs.map(\.x) } == [[0], [0]])
    }

    @Test(
        "a title naming a style the base theme no longer holds stops",
        arguments: ["banner", "bannerHead", "heading", "headline"]
    )
    func refusesRemovedTitleStyle(_ style: String) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": "Hi", "style": "\#(style)", "position": [400, 225], "at": [0, 1] } ] }
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
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "title", "text": "a", "style": "callout", "position": [400, 225], "at": [0, 1] } ] }
            """#)

        // Then
        #expect(plan.clips[0].title?.layout.runs.first?.size == 40 * (1206 / 1920.0))
    }

    @Test("a nested document is planned on its own, with its own format, for a storyline clip and another clip")
    func plansNested() throws {
        // Given
        let nested = ##"{ "kind": "sequence", "format": { "size": [640, 480] }, "storyline": [ { "kind": "solid", "color": "#000000", "duration": 1 } ] }"##

        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [ { "kind": "media", "media": \#(nested), "at": 0 } ] }, { "kind": "media", "media": \#(nested) } ] }
            """#)

        // Then
        #expect(plan.format.size == Size(width: 1080, height: 1920))
        #expect(plan.clips[0].nested?.format.size == Size(width: 640, height: 480))
        #expect(plan.storyline[1].nested?.format.size == Size(width: 640, height: 480))
        #expect(plan.storyline[0].nested == nil)
    }

    @Test("how each clip is drawn is planned, with keyframes in sequence time and filter lengths scaled")
    func plansAppearance() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [2160, 3840] },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 2, "out": 8, "filter": "mine/grade", "connected": [
                { "kind": "title", "text": "a", "style": "title", "placement": "top", "at": [3, 5], "blend": "screen", "scale": 2,
                  "keyframes": [ { "at": 3, "opacity": 0 }, { "at": 4, "opacity": 1, "ease": "ease-in" } ] } ] } ],
              "clips": [
                { "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1] },
                { "kind": "adjustment", "adjust": ["mine/grade"], "mask": { "kind": "rect", "area": [0, 0, 10, 10] }, "at": [0, 1] } ] }
            """#

        // When
        let plan = try plan(document)

        // Then
        let graded = [
            FilterEntry(operations: [.saturation(amount: 1.25), .blur(radius: 4 * MergedTheme.base.lengthScale(at: 2160))])
        ]
        let title = plan.clips[0].appearance
        #expect(plan.storyline[0].filter.filter() == graded)
        #expect(title.drawing == .picture(ClipComposite(
            opacity: .keyframes([
                PropertyKeyframe(index: 0, at: 1, value: 0, ease: .linear),
                PropertyKeyframe(index: 1, at: 2, value: 1, ease: .easeIn)
            ]),
            blend: "screen"
        )))
        #expect(title.scale == .value(Scale(2)))
        #expect(title.rotation == .value(0))
        #expect(title.shape == nil)
        #expect(plan.clips[1].appearance.drawing == .picture(ClipComposite(opacity: .value(1), blend: "normal")))
        #expect(plan.clips[1].appearance.shape == ShapeAppearance(
            kind: .rect,
            geometry: .area(outset: .off, anchor: nil),
            radius: .off,
            trim: .value(.whole),
            fill: .off,
            stroke: .stroke(PathStroke(
                width: 8 * MergedTheme.base.lengthScale(at: 2160),
                paint: .color(MergedTheme.base.color("accent")),
                join: .round,
                cap: .butt,
                start: .none,
                end: .none
            )),
            shadow: .off
        ))
        #expect(plan.clips[2].appearance.filter.filter() == graded)
    }

    @Test("a storyline clip that writes none of its transform has the frame as its box and fills it exactly")
    func fillsFrameByDefault() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }
            """#)

        // Then
        #expect(plan.storyline[0].appearance == StorylineAppearance(
            box: ClipBox(size: Size(width: 1080, height: 1920), position: .value(Point(x: 540, y: 960)), anchor: Point(x: 540, y: 960)),
            opacity: .value(1),
            scale: .value(.identity),
            rotation: .value(0),
            blend: "normal",
            radius: .off,
            border: .off,
            shadow: .off
        ))
    }

    @Test("a storyline clip's anchor is named on the frame, its keyframes move to sequence time, its radius is a theme length, and its border and shadow are the theme's")
    func plansStorylineTransform() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 2, "out": 8, "anchor": "top-left", "rotation": 90, "blend": "screen",
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
                PropertyKeyframe(index: 0, at: 1, value: Point(x: 0, y: 0), ease: .linear),
                PropertyKeyframe(index: 1, at: 3, value: Point(x: 540, y: 960), ease: .linear)
            ]),
            anchor: Point(x: 0, y: 0)
        ))
        #expect(appearance.scale == .keyframes([
            PropertyKeyframe(index: 0, at: 1, value: Scale(1), ease: .linear),
            PropertyKeyframe(index: 1, at: 3, value: Scale(0.5), ease: .linear)
        ]))
        #expect(appearance.rotation == .value(90))
        #expect(appearance.opacity == .value(1))
        #expect(appearance.blend == "screen")
        #expect(appearance.radius.cornerRadii() == CornerRadii(12 * scale))
        #expect(appearance.border.border() == MediaBorder(width: 4 * scale, color: theme.color("accent")))
        #expect(appearance.shadow.shadow() == DropShadow(
            radius: 32 * scale,
            offset: Point(x: 0, y: 12 * scale),
            color: theme.color("shadow")
        ))
    }

    @Test("a filter naming a preset that is not there stops where it is written")
    func refusesUnknownFilter() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "filter": ["mine/grade", "mine/cold"] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error == .unknownPreset(place: Place.root.appending(key: "storyline").appending(index: 0).appending(key: "filter").appending(index: 1), kind: .clip(.media(.video)), preset: UnknownPreset(kind: .filter, name: "mine/cold", hint: .pack(pack: "mine", names: ["mine/grade"], nearest: nil))))
    }

    @Test("each mask geometry form resolves in the clip's space, its feather times the length scale and its keys defaulted")
    func resolvesMaskForms() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [3840, 2160] }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [
                { "kind": "adjustment", "adjust": "frames/warm", "at": [0, 1], "mask": [
                    { "kind": "rect", "area": [10, 20, 100, 50], "radius": 6, "feather": 3, "invert": true, "mode": "subtract" },
                    { "kind": "ellipse", "area": [0, 0, 40, 20] },
                    { "kind": "rect", "width": 100, "height": 40, "position": [200, 300] },
                    { "kind": "ellipse", "width": 60, "height": 30, "position": [30, 15], "mode": "intersect" },
                    { "kind": "path", "points": [[0, 0], [100, 0], [50, 80]], "feather": 1 } ] } ] }
            """#)

        // Then
        #expect(plan.clips[0].mask == [
            ResolvedMask(
                geometry: .rect(Rectangle(x: 10, y: 20, width: 100, height: 50), radius: 6),
                feather: 6,
                isInverted: true,
                mode: .subtract
            ),
            mask(.ellipse(Rectangle(x: 0, y: 0, width: 40, height: 20))),
            box(.rect, width: 100, height: 40, position: Point(x: 200, y: 300)),
            box(.ellipse, width: 60, height: 30, position: Point(x: 30, y: 15), mode: .intersect),
            mask(.polyline([Point(x: 0, y: 0), Point(x: 100, y: 0), Point(x: 50, y: 80)], isClosed: true), feather: 2)
        ])
    }

    @Test("a mask moved only in keyframes takes its geometry from them, each leaf keyed where its keyframes write it")
    func resolvesKeyframedMasks() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [
                { "kind": "adjustment", "adjust": "frames/warm", "at": [0, 4], "mask": [ { "kind": "rect" }, { "kind": "path", "mode": "subtract" } ], "keyframes": [
                    { "at": 1, "ease": "ease-in", "mask": [ { "area": [0, 0, 100, 100], "radius": 4 }, { "points": [[0, 0], [10, 0], [5, 10]] } ] },
                    { "at": 2, "mask": [ { "feather": 2 }, { } ] },
                    { "at": 3, "mask": [ { "area": [50, 50, 200, 100], "radius": 8 }, { "points": [[0, 10], [10, 10], [5, 20]] } ] } ] } ] }
            """#)

        // Then
        let masks = try #require(plan.clips[0].mask)
        let triangle = { (y: Double) in [Point(x: 0, y: y), Point(x: 10, y: y), Point(x: 5, y: y + 10)] }
        #expect(masks.map { $0.sampled(at: SampleTime(1)) } == [
            MaskSample(
                geometry: .rect(Rectangle(x: 0, y: 0, width: 100, height: 100), radius: 4),
                feather: 2,
                isInverted: false,
                mode: .add
            ),
            MaskSample(geometry: .polyline(triangle(0), isClosed: true), feather: 0, isInverted: false, mode: .subtract)
        ])
        #expect(masks.map { $0.sampled(at: SampleTime(3)) } == [
            MaskSample(
                geometry: .rect(Rectangle(x: 50, y: 50, width: 200, height: 100), radius: 8),
                feather: 2,
                isInverted: false,
                mode: .add
            ),
            MaskSample(geometry: .polyline(triangle(10), isClosed: true), feather: 0, isInverted: false, mode: .subtract)
        ])
        guard case let .rect(.area(.keyframes(area)), _) = masks[0].geometry else {
            Issue.record("expected a rect mask given by its area as keyframes")
            return
        }
        #expect(area.map(\.at) == [1, 3])
        #expect(area[0].ease == .easeIn)
        #expect(masks[0].feather.map(\.at) == [2])
    }

    @Test(
        "a keyframed mask stops on a list of another length, a static leaf, another geometry form or another number of points",
        arguments: [
            (
                "clips",
                #"{ "shape": "rect" }"#,
                #"{ "area": [0, 0, 10, 10] }"#,
                #"[ { "area": [0, 0, 10, 10] }, { "area": [0, 0, 20, 20] } ]"#,
                "clips[0].keyframes[1].mask (keyframe): lists of different lengths: 1, 2"
            ),
            (
                "clips",
                #"{ "shape": "rect" }"#,
                #"{ "area": [0, 0, 10, 10] }"#,
                #"{ "shape": "ellipse", "area": [0, 0, 10, 10] }"#,
                "clips[0].keyframes[1].mask.shape (keyframe): a name, a boolean, a form or a static number is static and is written on the clip or the sequence, not in a keyframe"
            ),
            (
                "clips",
                #"{ "shape": "rect" }"#,
                #"{ "area": [0, 0, 10, 10] }"#,
                #"{ "width": 10 }"#,
                "clips[0].keyframes[1].mask.width (keyframe): the clip and its keyframes write different forms: area, width"
            ),
            (
                "clips",
                #"{ "shape": "rect" }"#,
                #"{ "area": [0, 0, 10, 10] }"#,
                #"{ "area": [0, 0, 10, 10], "invert": true }"#,
                "clips[0].keyframes[1].mask.invert (keyframe): a name, a boolean, a form or a static number is static and is written on the clip or the sequence, not in a keyframe"
            ),
            (
                "clips",
                #"[ { "shape": "rect" }, { "shape": "rect", "area": [0, 0, 5, 5] } ]"#,
                #"[ { "area": [0, 0, 10, 10] }, { "feather": 1 } ]"#,
                #"[ { "area": [0, 0, 10, 10] }, { "mode": "subtract" } ]"#,
                "clips[0].keyframes[1].mask[1].mode (keyframe): a name, a boolean, a form or a static number is static and is written on the clip or the sequence, not in a keyframe"
            ),
            (
                "clips",
                #"{ "shape": "path" }"#,
                #"{ "points": [[0, 0], [10, 0], [5, 10]] }"#,
                #"{ "points": [[0, 0], [10, 0], [10, 10], [0, 10]] }"#,
                "clips[0].keyframes[1].mask.points (keyframe): lists of different lengths: 3, 4"
            ),
            (
                "storyline",
                #"{ "shape": "rect" }"#,
                #"{ "area": [0, 0, 10, 10] }"#,
                #"{ "shape": "ellipse" }"#,
                "storyline[0].keyframes[1].mask.shape (keyframe): a name, a boolean, a form or a static number is static and is written on the clip or the sequence, not in a keyframe"
            )
        ]
    )
    func refusesDifferingMaskKeyframes(
        list: String,
        written: String,
        first: String,
        second: String,
        message: String
    ) throws {
        // Given
        let keyframes = #""mask": \#(written), "keyframes": [ { "at": 0, "mask": \#(first) }, { "at": 1, "mask": \#(second) } ]"#
        let document = list == "clips"
            ? #"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [ { "kind": "adjustment", "adjust": "frames/warm", "at": [0, 2], \#(keyframes) } ] }"#
            : #"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", \#(keyframes) } ] }"#

        // When, Then
        let error = #expect(throws: (any Error).self) { try plan(document) }
        #expect(error.map(String.init(describing:)) == message)
    }

    @Test("a failing shaping provider stops, naming the place that asked it, then its message")
    func namesFailingProvider() throws {
        // Given
        let sut = SequencePlanner(
            shaper: FailingShaper(ProviderFailure("no model")),
            presets: Fixture.presets,
            library: Fixture.library
        )
        let time = try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "connected": [ { "kind": "title", "text": "Hi", "style": "title", "at": [0, 1] } ] } ] }
            """#))

        // When
        let error = #expect(throws: ProviderError.self) { try sut.plan(time) }

        // Then
        #expect(error?.description == "storyline[0].connected[0].text (title): the shaping provider failed: no model")
    }

    // MARK: - Private
    private func mask(
        _ geometry: PathGeometry,
        feather: Double = 0,
        mode: MaskMode = .add,
        at time: Double = 0
    ) -> ResolvedMask {
        ResolvedMask(geometry: geometry, feather: feather, isInverted: false, mode: mode, at: time)
    }

    private func box(
        _ shape: ShapeKind,
        width: Double,
        height: Double,
        position: Point,
        mode: MaskMode = .add
    ) -> ResolvedMask {
        let box = ResolvedMaskRectangle.box(
            width: .keyframes([Keyframe(at: 0, value: width)]),
            height: .keyframes([Keyframe(at: 0, value: height)]),
            position: .keyframes([Keyframe(at: 0, value: .point(position))])
        )
        let geometry: ResolvedMaskGeometry = shape == .rect ? .rect(box, radius: .keyframes([Keyframe(at: 0, value: 0)])) : .ellipse(box)

        return ResolvedMask(geometry: geometry, feather: [Keyframe(at: 0, value: 0)], isInverted: false, mode: mode)
    }

    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }

    // The track data the fake tracker gives for [100, 100, 200, 40] followed in `/abs/screen.mp4` from media second 1.5,
    // over the media the storyline clip draws.
    private func data(followed: ClosedRange<Double>? = nil) -> String {
        TrackerTable(
            frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes],
            followed: followed.map { ["/abs/screen.mp4": $0] } ?? [:]
        )
        .data(Quad(Fixture.total), in: "/abs/screen.mp4", atMediaTime: 1.5, over: 1...3)
    }
}
