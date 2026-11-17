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
    @Test("the format defaults to the size of the first video on the storyline, rounded to even numbers, all content")
    func defaultsFormatToFirstVideo() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/card.png", "duration": 1 }, { "media": "/abs/halfway.mp4" } ] }
            """#)

        // Then
        #expect(plan.format == FormatPlan(
            size: Size(width: 1080, height: 1920),
            content: Rectangle(x: 0, y: 0, width: 1080, height: 1920),
            conform: .fit,
            background: Color(written: "#FFFFFF"),
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

    @Test("a written size and inset give the content rect, and conform, fps and background are kept")
    func readsWrittenFormat() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence",
              "format": { "size": [1081, 1920], "fps": 60, "background": "accent", "inset": [100, 20, 300, 40], "conform": "fill" },
              "storyline": [ { "media": "/abs/run.mp4" } ] }
            """#)

        // Then
        #expect(plan.format == FormatPlan(
            size: Size(width: 1081, height: 1920),
            content: Rectangle(x: 40, y: 100, width: 1021, height: 1520),
            conform: .fill,
            background: Color(written: "#ED2929"),
            fps: 60,
            duration: 30
        ))
    }

    @Test(
        "a format without a size on a storyline of no video that starts with a solid stops, as does an inset leaving no content",
        arguments: [
            (
                ##"{ "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 1 }, { "media": "/abs/card.png", "duration": 1 } ] }"##,
                #"top level (sequence): the storyline has no video and its first clip is a solid, which has no size, so the format needs "size""#
            ),
            (
                #"{ "kind": "sequence", "format": { "inset": [1000, 0, 920, 0] }, "storyline": [ { "media": "/abs/run.mp4" } ] }"#,
                "format.inset (sequence): the inset leaves no content rect in the output of 1080x1920"
            )
        ]
    )
    func refusesFormat(
        document: String,
        message: String
    ) throws {
        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == message)
    }

    @Test("a storyline crop is found in its media and grows by the crop padding, in that picture's pixels")
    func findsStorylineCrop() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "crop": "Total" }, { "media": "/abs/short.mp4", "crop": [0, 0, 540, 960] } ] }
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
            isBand: false,
            mediaTime: 0,
            lines: []
        )))
    }

    @Test("a parented area is found in its storyline clip's picture and grows by the area padding of that picture")
    func findsParentedArea() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/short.mp4", "connected": [ { "shape": "box", "area": "Send" } ] } ] }
            """#)

        // Then
        guard case let .value(area) = plan.clips[0].area else {
            Issue.record("the area was not found")
            return
        }
        let padding = 14 * 1080 / 1206.0
        #expect(abs(area.rectangle.x - (Fixture.send.x - padding)) < 1e-9)
        #expect(abs(area.rectangle.width - (Fixture.send.width + padding * 2)) < 1e-9)
        #expect(area.lines.map(\.text) == ["Send"])
    }

    @Test("a sequence clip's area is in output pixels")
    func keepsSequenceArea() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ],
              "clips": [ { "shape": "box", "area": [10, 20, 30, 40], "at": [0, 1] } ] }
            """#)

        // Then
        #expect(plan.clips[0].area == .value(FoundArea(
            rectangle: Rectangle(x: 10, y: 20, width: 30, height: 40),
            target: Rectangle(x: 10, y: 20, width: 30, height: 40),
            isBand: false,
            mediaTime: 0,
            lines: []
        )))
    }

    @Test("a parented position given by an area is the point it names, padding included")
    func findsAreaPosition() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "connected": [
                { "title": "a", "style": "label", "parent": true, "anchor": "right", "position": { "area": "Total", "point": "left" } },
                { "title": "b", "style": "label", "position": [10, 20] } ] } ] }
            """#)

        // Then
        #expect(plan.clips[0].position == .value(Point(x: 86, y: 120)))
        #expect(plan.clips[1].position == .value(Point(x: 10, y: 20)))
    }

    @Test(
        "a position given by an area on a clip that is not parented stops, naming where it is written",
        arguments: [
            (#""position": { "area": "Total", "point": "left" }"#, "storyline[0].connected[0].position"),
            (#""keyframes": [ { "at": 0, "position": [0, 0] }, { "at": 1, "position": { "area": "Total", "point": "left" } } ]"#, "storyline[0].connected[0].keyframes[1].position")
        ]
    )
    func refusesAreaPositionWithoutParent(
        keys: String,
        place: String
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "connected": [ { "title": "a", "style": "label", \#(keys) } ] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == #"\#(place) (title): a position given by an area is in the picture of a parented clip, so it needs "parent": true"#)
    }

    @Test("a media clip's crop is found in its own media, at its own media time")
    func findsMediaClipCrop() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "connected": [ { "media": "/abs/screen.mp4", "in": 1.5, "at": 0, "crop": "Total" } ] } ] }
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
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 1, "out": 3,
              "connected": [ { "shape": "box", "area": "Total", "at": [1.5, 2.5], "track": "Total" } ] } ] }
            """#)))

        // Then
        #expect(plan.storyline[0].track == nil)
        #expect(plan.clips[0].track?.target == Fixture.total)
        #expect(plan.time.clips[0].visible == TimeRange(start: 0.5, end: 1))
    }

    @Test("keyframes that all fall outside the window tracking narrowed stop, on the narrowed window")
    func refusesKeyframesOutsideNarrowedWindow() throws {
        // Given
        let sut = planner(followed: 0...1.9)
        let time = try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 1, "out": 3,
              "connected": [ { "shape": "box", "area": "Total", "at": [1.5, 2.5], "track": "Total",
                               "keyframes": [ { "at": 2.2, "opacity": 0 }, { "at": 2.4, "opacity": 1 } ] } ] } ] }
            """#))

        // When, Then
        #expect(throws: Never.self) { try Fixture.sequencePlanner.plan(time) }
        let error = #expect(throws: ResolveError.self) { try sut.plan(time) }
        #expect(error?.description == #"storyline[0].connected[0].keyframes (box): every keyframe of "opacity" lies outside [0.5, 1), so only one of its values would ever show"#)
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
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ { "title": "\#(word) \#(word)", "style": "banner", "placement": "top", "at": [0, 1]\#(width) } ] }
            """#)

        // Then
        #expect(plan.clips[0].title?.lineCount == lineCount)
    }

    @Test("a title is set at the length scale of the output")
    func scalesTitle() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "format": { "size": [2412, 5244] }, "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ { "title": "a", "style": "banner", "placement": "top", "at": [0, 1] } ] }
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
            + #"which hold "banner", "bannerHead", "heading", "headline", "label", "subtitle""#)
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
        #expect(plan.clips[0].title?.runs.first?.size == 40)
    }

    @Test("a label is set on one line in the label style and goes on the side that fits")
    func placesLabel() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "connected": [ { "shape": "box", "area": "Total", "label": "Total" } ] } ] }
            """#)

        // Then
        let label = try #require(plan.clips[0].label)
        #expect(label.side == .right)
        #expect(label.instant == 0)
        #expect(label.text.lineCount == 1)
        #expect(label.text.size == Size(width: 5 * 18 + 32, height: 36 * 1.25 + 16))
    }

    @Test("a label is measured at the first instant of the window tracking leaves")
    func measuresLabelAfterTracking() throws {
        // Given
        let sut = planner(followed: 1.5...3)

        // When
        let plan = try sut.plan(Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 1, "out": 3, "connected": [
                { "shape": "box", "at": [1, 3], "track": true, "label": "a",
                  "keyframes": [ { "at": 2, "area": "Total" }, { "at": 2.5, "area": "Total" } ] } ] } ] }
            """#)))

        // Then
        #expect(plan.time.clips[0].visible == TimeRange(start: 0.5, end: 2))
        #expect(plan.clips[0].label?.instant == 0.5)
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
        #expect(plan.clips[0].nested?.size == Size(width: 640, height: 480))
        #expect(plan.storyline[1].nested?.size == Size(width: 640, height: 480))
        #expect(plan.storyline[0].nested == nil)
    }

    // MARK: - Private
    @Test("how each clip is drawn is planned, with keyframes in sequence time and filter lengths scaled")
    func plansAppearance() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [2160, 3840] },
              "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "filter": "grade", "connected": [
                { "title": "a", "style": "label", "placement": "top", "at": [3, 5], "blend": "screen", "scale": 2,
                  "keyframes": [ { "at": 3, "opacity": 0 }, { "at": 4, "opacity": 1, "ease": "ease-in" } ] } ] } ],
              "clips": [
                { "shape": "box", "area": [0, 0, 10, 10], "at": [0, 1] },
                { "adjust": ["grade", "none"], "area": [0, 0, 10, 10], "at": [0, 1] } ] }
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
        #expect(plan.clips[1].appearance.shape == .box(
            width: MergedTheme.base.boxWidth * MergedTheme.base.lengthScale(at: 2160),
            radius: MergedTheme.base.boxRadius * MergedTheme.base.lengthScale(at: 2160),
            color: MergedTheme.base.shapeColor(of: .box)
        ))
        #expect(plan.clips[2].appearance.filter == graded)
    }

    @Test("a filter naming a preset that is not there stops where it is written")
    func refusesUnknownFilter() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "filter": ["grade", "cold"] } ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error == .unknownPreset(place: Place.root.appending(key: "storyline").appending(index: 0).appending(key: "filter").appending(index: 1), kind: .clip(.media(.video)), presetKind: "filter", name: "cold"))
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
