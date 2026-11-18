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
            #"storyline[0].connected[0].track (rect): "track": true follows the clip's own area or crop, and it has none given as an area"#
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
        let plan = try sut.plan(time, crops: [nil], areas: [])

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
        let error = #expect(throws: ResolveError.self) { try sut.plan(time, crops: [nil], areas: []) }
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
        let plan = try sut.plan(time, crops: [nil, nil], areas: [])

        // Then
        let track = try #require(plan.storyline[0])
        #expect(time.storyline[0].drawn.end > time.storyline[0].edit.end)
        #expect(track.frames.last?.time == 3)
        #expect(track.motion(atMediaTime: 3.4) == track.motion(atMediaTime: 3))
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
        let staticPlan = try sut.plan(staticTime, crops: [.value(found(total, at: 1))], areas: [])
        let keyframedPlan = try sut.plan(
            keyframedTime,
            crops: [.keyframes([
                TimedValue(index: 0, at: 1.5, value: found(Rectangle(x: 0, y: 0, width: 603, height: 1311), at: 2.5), ease: .linear),
                TimedValue(index: 1, at: 0.5, value: found(crop, at: 1.5), ease: .linear)
            ])],
            areas: []
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
            try sut.plan(time, crops: [.value(found(total, at: 1))], areas: [])
        }
        #expect(error?.description == #"""
            storyline[0]#screen.track (video): "track": true follows the clip's own area or crop, and it has none given as \#
            an area
            """#)
    }

    @Test("a clip parented to its storyline clip follows that clip's media from its instant, and is visible only where followed")
    func narrowsConnectedWindow() throws {
        // Given
        let sut = planner(followed: 0...1.9)
        let time = try plan(connected: #"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total" }, "at": [1.5, 2.5], "track": { "text": "Total" } }"#)

        // When
        let plan = try sut.plan(time, crops: [nil], areas: [nil])

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
        let plan = try sut.plan(time, crops: [nil], areas: [nil])

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
            areas: [.keyframes([
                TimedValue(index: 1, at: 1.2, value: found(total, at: 2.2), ease: .linear),
                TimedValue(index: 0, at: 0.8, value: found(first, at: 1.8), ease: .linear)
            ])]
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
        let error = #expect(throws: ResolveError.self) { try sut.plan(time, crops: [nil], areas: [nil]) }
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
            try sut.plan(time, crops: time.storyline.map { _ in nil }, areas: time.clips.map { _ in nil })
        }
        #expect(error?.description == message)
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
