//
//  TrackPlannerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// `/abs/screen.mp4` has a frame every 0.1 media seconds. Its storyline clip plays media [1, 3) over the edit range
// [0, 2), and "Total" is on every frame. The fake tracker moves the target 10 pixels down per media second.
@Suite("TrackPlanner Tests")
struct TrackPlannerTests {
    // MARK: - Property
    private static let untrackable: [(String, String)] = [
        (
            #"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "track": { "text": "Total" } } ] }"#,
            "clips[0].track (rect): track follows the video or image sequence of the clip's storyline parent, and there is none to follow here"
        ),
        (
            #"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "connected": [ { "title": "a", "style": "title", "at": [0, 1], "track": { "text": "Total" } } ] } ] }"#,
            "storyline[0].connected[0].track (title): track follows the video or image sequence of the clip's storyline parent, and there is none to follow here"
        ),
        (
            #"{ "kind": "sequence", "storyline": [ { "id": "page", "media": "/abs/page.png", "duration": 2, "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Total" }, "parent": "page", "track": { "text": "Total" } } ] } ] }"#,
            "storyline[0]#page.connected[0].track (rect): track follows the video or image sequence of the clip's storyline parent, and there is none to follow here"
        ),
        (
            ##"{ "kind": "sequence", "storyline": [ { "media": { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 2 } ] }, "track": { "text": "Total" } } ] }"##,
            "storyline[0].track (compound): track follows the video or image sequence of the clip's storyline parent, and there is none to follow here"
        ),
        (
            #"{ "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [ { "title": "a", "style": "title", "parent": "screen", "position": [0, 0], "track": true } ] } ] }"#,
            #"storyline[0]#screen.connected[0].track (title): a title or media clip names the area it tracks, so it cannot take "track": true"#
        ),
        (
            #"{ "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [ { "media": "/abs/page.png", "parent": "screen", "position": [0, 0], "track": true } ] } ] }"#,
            #"storyline[0]#screen.connected[0].track (image): a title or media clip names the area it tracks, so it cannot take "track": true"#
        ),
        (
            #"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "at": [0, 1], "track": true } ] } ] }"#,
            #"storyline[0].connected[0].track (rect): "track": true follows the clip's own area, mask or crop, and it has none given as an area"#
        ),
        (
            #"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ { "id": "card", "media": "/abs/screen.mp4", "at": [0, 1], "width": 300 }, { "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "card", "track": { "text": "Total" } } ] }"#,
            #"clips[1].track (rect): track follows the media of a storyline parent, and the parent "card" is a connected or sequence clip, whose media is not followed"#
        )
    ]

    private let total = Rectangle(x: 100, y: 100, width: 200, height: 40)
    private let ocr = OCRTable(file: "/abs/screen.mp4", lines: [
        RecognisedLine(text: "Total", rectangle: Rectangle(x: 100, y: 100, width: 200, height: 40))
    ])

    // MARK: - Initializer
    // MARK: - Test
    @Test("a storyline clip follows the area it names, before padding, from its in over every frame it draws")
    func followsStorylineTarget() throws {
        // Given
        let sut = planner()
        let time = try plan(storyline: #""track": { "text": "Total" }"#)

        // When
        let plan = try sut.plan(time, crops: [nil], storylineMasks: time.storyline.map { _ in nil }, areas: [], masks: time.clips.map { _ in nil })

        // Then
        let track = try #require(plan.storyline[0])
        #expect(track.target == total)
        #expect(track.mediaTime == 1)
        #expect(track.frames.first?.time == 1)
        #expect(track.frames.last?.time == 3)
        #expect(track.frames.count == 21)
        #expect(track.motion(atMediaTime: 2) == TrackMotion(from: total, to: moved(total, down: 10)))
    }

    @Test("a storyline clip that loses its target inside its edit range stops, naming where it was followed")
    func refusesLostStorylineTarget() throws {
        // Given
        let sut = planner(followed: 0...2.4)
        let time = try plan(storyline: #""track": { "text": "Total" }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(time, crops: [nil], storylineMasks: time.storyline.map { _ in nil }, areas: [], masks: time.clips.map { _ in nil }) }
        #expect(error?.description == #"""
            storyline[0]#screen.track (video): the tracker follows its target only over [0, 1.5) and loses it inside the \#
            edit range [0, 2)
            """#)
    }

    @Test("a target lost only in a handle holds the nearest frame followed there")
    func holdsInHandle() throws {
        // Given
        let sut = planner(followed: 0...3)
        let time = try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [
                { "media": "/abs/screen.mp4", "in": 1, "out": 3, "track": { "text": "Total" } },
                { "solid": "#000000", "duration": 2, "transition": { "preset": "frames/flash", "seconds": 1 } } ] }
            """#))

        // When
        let plan = try sut.plan(time, crops: [nil, nil], storylineMasks: time.storyline.map { _ in nil }, areas: [], masks: time.clips.map { _ in nil })

        // Then
        let track = try #require(plan.storyline[0])
        #expect(time.storyline[0].drawn.end > time.storyline[0].edit.end)
        #expect(track.frames.last?.time == 3)
        #expect(track.motion(atMediaTime: 3.4) == track.motion(atMediaTime: 3))
    }

    @Test("a reversed storyline clip is followed from the lowest to the highest media time it shows")
    func followsReversedClip() throws {
        // Given
        let sut = planner()
        let reverse = #""keyframes": [ { "at": 1, "timeRemap": 3 }, { "at": 3, "timeRemap": 1 } ]"#
        let time = try plan(storyline: #""track": { "text": "Total" }, \#(reverse)"#)

        // When
        let plan = try sut.plan(time, crops: [nil], storylineMasks: [nil], areas: [], masks: [])

        // Then
        let track = try #require(plan.storyline[0])
        #expect(track.mediaTime == 3)
        #expect(track.frames.first?.time == 1)
        #expect(track.frames.last?.time == 3)
        #expect(track.frames.count == 21)
    }

    @Test("a clip under a reversed storyline clip is visible on the frames that show a followed media frame")
    func narrowsUnderReversedClip() throws {
        // Given
        // The media time is 3 - s at sequence time s, and the target is followed from media second 2 to 3. At 24 fps
        // frame 24 shows media second 2 and frame 25 the frame at 1.9.
        let sut = planner(followed: 2...3)
        let time = try plan(
            storyline: #""keyframes": [ { "at": 1, "timeRemap": 3 }, { "at": 3, "timeRemap": 1 } ]"#,
            connected: #"""
                { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total" }, "track": { "text": "Total" } }
                """#
        )

        // When
        let plan = try sut.plan(time, crops: [nil], storylineMasks: [nil], areas: [nil], masks: [nil])

        // Then
        let track = try #require(plan.clips[0])
        #expect(track.mediaTime == 3)
        #expect(track.frames.map(\.time) == (20...30).map { Double($0) / 10 })
        #expect(time.fps == 24)
        #expect(plan.time.clips[0].visible == TimeRange(start: 0, end: 25.0 / 24))
    }

    @Test("true on a storyline clip follows its crop, at its first keyframe when the crop is keyframed")
    func followsOwnCrop() throws {
        // Given
        let sut = planner()
        let staticTime = try plan(storyline: #""crop": { "text": "Total" }, "track": true"#)
        let keyframedTime = try plan(storyline: #"""
            "track": true, "keyframes": [ { "at": 2.5, "crop": { "scale": 2 } }, { "at": 1.5, "crop": { "text": "Total" } } ]
            """#)
        let crop = Rectangle(x: 120, y: 300, width: 400, height: 300)

        // When
        let staticPlan = try sut.plan(staticTime, crops: [.value(found(total, at: 1))], storylineMasks: staticTime.storyline.map { _ in nil }, areas: [], masks: staticTime.clips.map { _ in nil })
        let keyframedPlan = try sut.plan(
            keyframedTime,
            crops: [.keyframes([
                TimedValue(index: 0, at: 1.5, value: found(Rectangle(x: 0, y: 0, width: 603, height: 1311), at: 2.5), ease: .linear),
                TimedValue(index: 1, at: 0.5, value: found(crop, at: 1.5), ease: .linear)
            ])],
            storylineMasks: keyframedTime.storyline.map { _ in nil },
            areas: [],
            masks: keyframedTime.clips.map { _ in nil }
        )

        // Then
        #expect(staticPlan.storyline[0]?.target == total)
        #expect(staticPlan.storyline[0]?.mediaTime == 1)
        #expect(keyframedPlan.storyline[0]?.target == crop)
        #expect(keyframedPlan.storyline[0]?.mediaTime == 1.5)
    }

    @Test(
        "true on a storyline clip whose crop does not start as an area stops",
        arguments: [
            #""track": true"#,
            #""track": true, "crop": { "scale": 2 }"#,
            #""track": true, "keyframes": [ { "at": 1.5, "crop": { "scale": 2 } }, { "at": 2, "crop": { "text": "Total" } } ]"#
        ]
    )
    func refusesOwnCropWithoutArea(keys: String) throws {
        // Given
        let sut = planner()
        let time = try plan(storyline: keys)

        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try sut.plan(time, crops: [.value(found(total, at: 1))], storylineMasks: time.storyline.map { _ in nil }, areas: [], masks: time.clips.map { _ in nil })
        }
        #expect(error?.description == #"""
            storyline[0]#screen.track (video): "track": true follows the clip's own area, mask or crop, and it has none \#
            given as an area
            """#)
    }

    @Test("a clip parented to its storyline clip follows that clip's media from its instant, and is visible only where followed")
    func narrowsConnectedWindow() throws {
        // Given
        let sut = planner(followed: 0...1.9)
        let time = try plan(connected: #"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total" }, "at": [1.5, 2.5], "track": { "text": "Total" } }"#)

        // When
        let plan = try sut.plan(time, crops: [nil], storylineMasks: time.storyline.map { _ in nil }, areas: [nil], masks: time.clips.map { _ in nil })

        // Then
        let track = try #require(plan.clips[0])
        #expect(track.target == total)
        #expect(track.mediaTime == 1.5)
        #expect(track.frames.first?.time == 1)
        #expect(plan.time.clips[0].visible == TimeRange(start: 0.5, end: 1))
        #expect(plan.time.clips[0].window == time.clips[0].window)
    }

    @Test("a clip parented to its storyline clip without at finds its target at that clip's in")
    func findsTargetAtStorylineIn() throws {
        // Given
        let sut = planner()
        let time = try plan(connected: #"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total" }, "track": { "text": "Total" } }"#)

        // When
        let plan = try sut.plan(time, crops: [nil], storylineMasks: time.storyline.map { _ in nil }, areas: [nil], masks: time.clips.map { _ in nil })

        // Then
        #expect(plan.clips[0]?.mediaTime == 1)
        #expect(plan.time.clips[0].visible == time.clips[0].visible)
    }

    @Test("true on a shape follows its own area, at its first keyframe when the area is keyframed")
    func followsOwnArea() throws {
        // Given
        let sut = planner()
        let time = try plan(connected: #"""
            { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "track": true, "keyframes": [ { "at": 1.8, "area": { "text": "Total" } }, { "at": 2.2, "area": { "text": "Total" } } ] }
            """#)
        let first = Rectangle(x: 10, y: 20, width: 30, height: 40)

        // When
        let plan = try sut.plan(
            time,
            crops: [nil],
            storylineMasks: time.storyline.map { _ in nil },
            areas: [.keyframes([
                TimedValue(index: 1, at: 1.2, value: found(total, at: 2.2), ease: .linear),
                TimedValue(index: 0, at: 0.8, value: found(first, at: 1.8), ease: .linear)
            ])],
            masks: time.clips.map { _ in nil }
        )

        // Then
        #expect(plan.clips[0]?.target == first)
        #expect(plan.clips[0]?.mediaTime == 1.8)
    }

    @Test("a connected clip whose target is followed on none of its visible frames stops")
    func refusesNeverFollowed() throws {
        // Given
        let sut = planner(followed: 3...3.9)
        let time = try plan(connected: #"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total" }, "at": [1.5, 2.5], "track": { "text": "Total" } }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(time, crops: [nil], storylineMasks: time.storyline.map { _ in nil }, areas: [nil], masks: time.clips.map { _ in nil }) }
        #expect(error?.description == #"""
            storyline[0]#screen.connected[0] (rect): never visible, since the tracker follows its target on none of the \#
            frames of its visible range [0.5, 1.5)
            """#)
    }

    @Test(
        "track stops where there is nothing to follow, and true where the clip has no area or names its target",
        arguments: untrackable
    )
    func refusesUntrackable(
        document: String,
        message: String
    ) throws {
        // Given
        let sut = planner()
        let time = try Fixture.planner.plan(document: Fixture.json(document))

        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try sut.plan(time, crops: time.storyline.map { _ in nil }, storylineMasks: time.storyline.map { _ in nil }, areas: time.clips.map { _ in nil }, masks: time.clips.map { _ in nil })
        }
        #expect(error?.description == message)
    }

    @Test("true on an adjustment follows the bounding box of its masks without feather, at its first keyframe when the masks are keyframed")
    func followsOwnMask() throws {
        // Given
        let sut = planner()
        let time = try plan(connected: #"""
            { "adjust": "frames/warm", "parent": "screen", "track": true, "mask": { "shape": "rect", "area": [0, 0, 10, 10] } }
            """#)
        let masks = [
            mask(.rect(Rectangle(x: 10, y: 20, width: 30, height: 40), radius: 4), feather: 50),
            mask(.polyline([Point(x: 50, y: 60), Point(x: 70, y: 60), Point(x: 60, y: 100)], isClosed: true))
        ]
        let later = [mask(.ellipse(total))]

        // When
        let staticPlan = try sut.plan(time, crops: [nil], storylineMasks: [nil], areas: [nil], masks: [.value(masks)])
        let keyframedPlan = try sut.plan(
            time,
            crops: [nil],
            storylineMasks: [nil],
            areas: [nil],
            masks: [.keyframes([
                TimedValue(index: 1, at: 1.2, value: later, ease: .linear),
                TimedValue(index: 0, at: 0.8, value: masks, ease: .linear)
            ])]
        )

        // Then
        #expect(staticPlan.clips[0]?.target == Rectangle(x: 10, y: 20, width: 60, height: 80))
        #expect(staticPlan.clips[0]?.mediaTime == 1)
        #expect(keyframedPlan.clips[0]?.target == Rectangle(x: 10, y: 20, width: 60, height: 80))
        #expect(keyframedPlan.clips[0]?.mediaTime == 1.8)
    }

    @Test("true on a storyline clip follows the bounding box of its masks in its own media")
    func followsStorylineMask() throws {
        // Given
        let sut = planner()
        let time = try plan(storyline: #""track": true"#)

        // When
        let plan = try sut.plan(
            time,
            crops: [nil],
            storylineMasks: [.value([mask(.ellipse(total)), mask(.rect(Rectangle(x: 300, y: 100, width: 20, height: 100), radius: 0))])],
            areas: [],
            masks: []
        )

        // Then
        #expect(plan.storyline[0]?.target == Rectangle(x: 100, y: 100, width: 220, height: 100))
        #expect(plan.storyline[0]?.mediaTime == 1)
    }

    @Test("true on a clip with more than one of an area, a mask and a crop stops, naming them")
    func refusesAmbiguousOwnTarget() throws {
        // Given
        let sut = planner()
        let shape = try plan(connected: #"""
            { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "track": true, "mask": { "shape": "rect", "area": [0, 0, 10, 10] } }
            """#)
        let storyline = try plan(storyline: #""crop": { "text": "Total" }, "track": true"#)
        let masks: PropertyValue<[ResolvedMask]> = .value([mask(.ellipse(total))])

        // When
        let shapeError = #expect(throws: ResolveError.self) {
            try sut.plan(shape, crops: [nil], storylineMasks: [nil], areas: [.value(found(total, at: 1))], masks: [masks])
        }
        let storylineError = #expect(throws: ResolveError.self) {
            try sut.plan(storyline, crops: [.value(found(total, at: 1))], storylineMasks: [masks], areas: [], masks: [])
        }

        // Then
        #expect(shapeError?.description == #"""
            storyline[0]#screen.connected[0].track (rect): "track": true follows one of the clip's area, mask and crop, \#
            and it has "area" and "mask", so it must name its target
            """#)
        #expect(storylineError?.description == #"""
            storyline[0]#screen.track (video): "track": true follows one of the clip's area, mask and crop, and it has \#
            "crop" and "mask", so it must name its target
            """#)
    }

    @Test("a storyline clip with an area crop and a mask follows the area it names, where true on it stops")
    func followsNamedTargetPastOwnCandidates() throws {
        // Given
        let sut = planner()
        let named = try plan(storyline: #""crop": { "text": "Total" }, "track": { "text": "Total" }"#)
        let own = try plan(storyline: #""crop": { "text": "Total" }, "track": true"#)
        let crops: [PropertyValue<FoundArea>?] = [.value(found(total, at: 1))]
        let masks: [PropertyValue<[ResolvedMask]>?] = [.value([mask(.ellipse(Rectangle(x: 0, y: 0, width: 50, height: 50)))])]

        // When
        let plan = try sut.plan(named, crops: crops, storylineMasks: masks, areas: [], masks: [])
        let error = #expect(throws: ResolveError.self) {
            try sut.plan(own, crops: crops, storylineMasks: masks, areas: [], masks: [])
        }

        // Then
        #expect(plan.storyline[0]?.target == total)
        #expect(plan.storyline[0]?.mediaTime == 1)
        #expect(error?.description == #"""
            storyline[0]#screen.track (video): "track": true follows one of the clip's area, mask and crop, and it has \#
            "crop" and "mask", so it must name its target
            """#)
    }

    @Test("true on a box shape does not follow its mask, which is in its own box, so it has nothing to follow")
    func refusesBoxShapeMask() throws {
        // Given
        let sut = planner()
        let time = try plan(connected: #"""
            { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "width": 100, "height": 50, "track": true, "mask": { "shape": "rect", "area": [0, 0, 10, 10] } }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try sut.plan(time, crops: [nil], storylineMasks: [nil], areas: [nil], masks: [.value([mask(.ellipse(total))])])
        }
        #expect(error?.description == #"""
            storyline[0]#screen.connected[0].track (rect): "track": true follows the clip's own area, mask or crop, and it \#
            has none given as an area
            """#)
    }

    // MARK: - Private
    private func planner(followed: ClosedRange<Double>? = nil) -> TrackPlanner {
        TrackPlanner(
            tracker: TrackerTable(
                frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes],
                followed: followed.map { ["/abs/screen.mp4": $0] } ?? [:],
                drift: Point(x: 0, y: 10)
            ),
            ocr: ocr
        )
    }

    private func plan(
        storyline keys: String = "",
        connected: String? = nil
    ) throws -> TimePlan {
        let clips = connected.map { #", "connected": [ \#($0) ]"# } ?? ""
        let separator = keys.isEmpty ? "" : ", "
        return try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [
                { "id": "screen", "media": "/abs/screen.mp4", "in": 1, "out": 3\#(separator)\#(keys)\#(clips) } ] }
            """#))
    }

    private func mask(
        _ geometry: PathGeometry,
        feather: Double = 0
    ) -> ResolvedMask {
        ResolvedMask(geometry: geometry, feather: feather, isInverted: false, mode: .add)
    }

    private func found(
        _ target: Rectangle,
        at mediaTime: Double
    ) -> FoundArea {
        FoundArea(rectangle: target.grown(by: 14), target: target, mediaTime: mediaTime, lines: [])
    }

    private func moved(
        _ rectangle: Rectangle,
        down distance: Double
    ) -> Rectangle {
        Rectangle(x: rectangle.x, y: rectangle.y + distance, width: rectangle.width, height: rectangle.height)
    }
}
