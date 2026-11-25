//
//  TrackPlannerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// `/abs/screen.mp4` has a frame every 0.1 media seconds. Its storyline clip plays media [1, 3) over the edit range
// [0, 2). The track data is what a fake tracker gives that moves the target 10 pixels down per media second.
@Suite("TrackPlanner Tests")
struct TrackPlannerTests {
    // MARK: - Property
    // Track data on one frame, which none of these clips reaches, since each has no media to follow.
    private static let track = #"{ "time": 1, "frames": [ { "time": 1, "quad": [[100, 100], [300, 100], [300, 140], [100, 140]] } ] }"#

    private static let untrackable: [(String, String)] = [
        (
            #"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "track": \#(track) } ] }"#,
            "clips[0].track (rect): track follows the video or image sequence of the clip or of its parent, and there is none to follow here"
        ),
        (
            #"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "connected": [ { "title": "a", "style": "title", "at": [0, 1], "track": \#(track) } ] } ] }"#,
            "storyline[0].connected[0].track (title): track follows the video or image sequence of the clip or of its parent, and there is none to follow here"
        ),
        (
            #"{ "kind": "sequence", "storyline": [ { "id": "page", "media": "/abs/page.png", "duration": 2, "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "area": [100, 100, 200, 40], "parent": "page", "track": \#(track) } ] } ] }"#,
            "storyline[0]#page.connected[0].track (rect): track follows the video or image sequence of the clip or of its parent, and there is none to follow here"
        ),
        (
            ##"{ "kind": "sequence", "storyline": [ { "media": { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 2 } ] }, "track": \##(track) } ] }"##,
            "storyline[0].track (compound): track follows the video or image sequence of the clip or of its parent, and there is none to follow here"
        ),
        (
            #"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ { "id": "card", "media": "/abs/page.png", "at": [0, 1], "width": 300 }, { "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "card", "track": \#(track) } ] }"#,
            "clips[1].track (rect): track follows the video or image sequence of the clip or of its parent, and there is none to follow here"
        )
    ]

    private let total = Rectangle(x: 100, y: 100, width: 200, height: 40)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a storyline clip follows its track data from the frame its time names over every frame it draws")
    func followsStorylineTarget() throws {
        // Given
        let sut = TrackPlanner()
        let trackData = data(atMediaTime: 1, over: 1...3)
        let time = try plan(storyline: #""track": \#(trackData)"#)

        // When
        let plan = try sut.plan(time)

        // Then
        let track = try #require(plan.storyline[0])
        #expect(track.target == Quad(total))
        #expect(track.mediaTime == 1)
        #expect(track.samples.first?.time == 1)
        #expect(track.samples.last?.time == 3)
        #expect(track.samples.count == 21)
        #expect(track.motion(atMediaTime: 2) == TrackMotion(from: Quad(total), to: Quad(moved(total, down: 10))))
    }

    @Test("a storyline clip that loses its target inside its edit range stops, naming where it was followed")
    func refusesLostStorylineTarget() throws {
        // Given
        let sut = TrackPlanner()
        let trackData = data(atMediaTime: 1, followed: 0...2.4, over: 1...3)
        let time = try plan(storyline: #""track": \#(trackData)"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(time) }
        #expect(error?.description == #"""
            storyline[0]#screen.track (video): the track data follows its target only over [0, 1.5) and loses it inside \#
            the edit range [0, 2)
            """#)
    }

    @Test("a target lost only in a handle holds the nearest frame followed there")
    func holdsInHandle() throws {
        // Given
        let sut = TrackPlanner()
        let trackData = data(atMediaTime: 1, followed: 0...3)
        let time = try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [
                { "media": "/abs/screen.mp4", "in": 1, "out": 3, "track": \#(trackData) },
                { "solid": "#000000", "duration": 2, "transition": { "preset": "frames/flash", "seconds": 1 } } ] }
            """#))

        // When
        let plan = try sut.plan(time)

        // Then
        let track = try #require(plan.storyline[0])
        #expect(time.storyline[0].drawn.end > time.storyline[0].edit.end)
        #expect(track.samples.last?.time == 3)
        #expect(track.motion(atMediaTime: 3.4) == track.motion(atMediaTime: 3))
    }

    @Test("a reversed storyline clip is followed from the lowest to the highest media time it shows")
    func followsReversedClip() throws {
        // Given
        let sut = TrackPlanner()
        let trackData = data(atMediaTime: 3, over: 1...3)
        let reverse = #""keyframes": [ { "at": 1, "timeRemap": 3 }, { "at": 3, "timeRemap": 1 } ]"#
        let time = try plan(storyline: #""track": \#(trackData), \#(reverse)"#)

        // When
        let plan = try sut.plan(time)

        // Then
        let track = try #require(plan.storyline[0])
        #expect(track.mediaTime == 3)
        #expect(track.samples.first?.time == 1)
        #expect(track.samples.last?.time == 3)
        #expect(track.samples.count == 21)
    }

    @Test("a clip under a reversed storyline clip is visible on the frames that show a followed media frame")
    func narrowsUnderReversedClip() throws {
        // Given
        // The media time is 3 - s at sequence time s, and the target is followed from media second 2 to 3. At 24 fps
        // frame 24 shows media second 2 and frame 25 the frame at 1.9.
        let sut = TrackPlanner()
        let trackData = data(atMediaTime: 3, followed: 2...3)
        let time = try plan(
            storyline: #""keyframes": [ { "at": 1, "timeRemap": 3 }, { "at": 3, "timeRemap": 1 } ]"#,
            connected: #"""
                { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [100, 100, 200, 40], "track": \#(trackData) }
                """#
        )

        // When
        let plan = try sut.plan(time)

        // Then
        let track = try #require(plan.clips[0]?.track)
        #expect(track.mediaTime == 3)
        #expect(track.samples.map(\.time) == (20...30).map { Double($0) / 10 })
        #expect(time.fps == 24)
        #expect(plan.time.clips[0].visible == TimeRange(start: 0, end: 25.0 / 24))
    }

    @Test("a clip that starts after its remapped storyline clip is followed from its own instant")
    func followsFromConnectedInstantUnderRemap() throws {
        // Given
        // The media time is 1 + s at sequence time s, and the target is followed from media second 1.5, so the
        // storyline clip's first frame shows a frame where it is lost and the connected clip's first frame one where
        // it is followed.
        let sut = TrackPlanner()
        let trackData = data(atMediaTime: 1.5, followed: 1.5...3)
        let time = try plan(
            storyline: #""keyframes": [ { "at": 1, "timeRemap": 1 }, { "at": 3, "timeRemap": 3 } ]"#,
            connected: #"""
                { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [100, 100, 200, 40], "at": [1.5, 2.5], "track": \#(trackData) }
                """#
        )

        // When
        let plan = try sut.plan(time)

        // Then
        let track = try #require(plan.clips[0]?.track)
        #expect(track.mediaTime == 1.5)
        #expect(track.samples.first?.time == 1.5)
        #expect(plan.time.clips[0].visible == TimeRange(start: 0.5, end: 1.5))
    }

    @Test("a clip whose instant shows a followed frame and whose window from it shows none stops as never visible")
    func refusesWindowNeverFollowed() throws {
        // Given
        // The media time is 1 + 2s at sequence time s, and the target is followed from media second 1.6. The clip's
        // instant 0.31 shows media time 1.62, a followed frame, and the 24 fps frame its window is walked from, frame 7
        // at 0.2917, shows media time 1.583, the frame at 1.5, which is not followed.
        let sut = TrackPlanner()
        let trackData = data(atMediaTime: 1.6, followed: 1.6...3.9)
        let time = try plan(
            storyline: #""keyframes": [ { "at": 1, "timeRemap": 1 }, { "at": 3, "timeRemap": 5 } ]"#,
            connected: #"""
                { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [100, 100, 200, 40], "at": [1.31, 2.5], "track": \#(trackData) }
                """#
        )

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(time) }
        #expect(error?.description == #"""
            storyline[0]#screen.connected[0] (rect): never visible, since the track data follows its target on none of \#
            the frames of its visible range [0.31, 1.5)
            """#)
    }

    @Test("a clip parented to its storyline clip follows that clip's media from its instant, and is visible only where followed")
    func narrowsConnectedWindow() throws {
        // Given
        let sut = TrackPlanner()
        let trackData = data(atMediaTime: 1.5, followed: 0...1.9, over: 1...3)
        let time = try plan(connected: #"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [100, 100, 200, 40], "at": [1.5, 2.5], "track": \#(trackData) }"#)

        // When
        let plan = try sut.plan(time)

        // Then
        let track = try #require(plan.clips[0]?.track)
        #expect(track.target == Quad(total))
        #expect(track.mediaTime == 1.5)
        #expect(track.samples.first?.time == 1)
        #expect(plan.time.clips[0].visible == TimeRange(start: 0.5, end: 1))
        #expect(plan.time.clips[0].window == time.clips[0].window)
    }

    @Test("a clip parented to a media clip follows that clip's media through its clock, and is visible only where followed")
    func followsMediaClipParent() throws {
        // Given
        // The card plays the screen from media time 0.5 at sequence time 0.5, so it shows media time t at t.
        let sut = TrackPlanner()
        let trackData = data(atMediaTime: 1, followed: 0...1.3, over: 1...2)
        let time = try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 1, "out": 3 } ], "clips": [
                { "id": "card", "media": "/abs/screen.mp4", "in": 0.5, "at": [0.5, 2], "width": 300 },
                { "shape": "rect", "stroke": { "width": 8 }, "parent": "card", "area": [100, 100, 200, 40], "at": [1, 1.5],
                  "track": \#(trackData) } ] }
            """#))

        // When
        let plan = try sut.plan(time)

        // Then
        let track = try #require(plan.clips[1])
        #expect(track.file.path == "/abs/screen.mp4")
        #expect(track.clock == time.clips[0].mediaClock)
        #expect(track.track.target == Quad(total))
        #expect(track.track.mediaTime == 1)
        #expect(track.track.samples.map(\.time) == [1, 1.1, 1.2, 1.3])
        // At 24 fps the frame at 34 / 24 is the first to show media time 1.4, which was not followed.
        #expect(plan.time.clips[1].visible == TimeRange(start: 1, end: 34.0 / 24))
    }

    @Test("a media clip of video follows its track data in its own media through its own clock, and is visible only where followed")
    func followsOwnMedia() throws {
        // Given
        // The clip plays the screen from media time 0.5 at sequence time 0.5, so it shows media time t at t, and it
        // has no parent to follow.
        let sut = TrackPlanner()
        let trackData = data(atMediaTime: 0.5, followed: 0...1.3, over: 0.5...2)
        let time = try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 1, "out": 3 } ], "clips": [
                { "media": "/abs/screen.mp4", "in": 0.5, "at": [0.5, 2], "width": 300, "track": \#(trackData) } ] }
            """#))

        // When
        let plan = try sut.plan(time)

        // Then
        let track = try #require(plan.clips[0])
        #expect(track.file.path == "/abs/screen.mp4")
        #expect(track.clock == time.clips[0].mediaClock)
        #expect(track.track.target == Quad(total))
        #expect(track.track.mediaTime == 0.5)
        #expect(track.track.samples.map(\.time) == [0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3])
        // At 24 fps the frame at 34 / 24 is the first to show media time 1.4, which was not followed.
        #expect(plan.time.clips[0].visible == TimeRange(start: 0.5, end: 34.0 / 24))
    }

    @Test("a media clip of video parented to a storyline clip follows its own media on its own clock, not its parent's")
    func followsOwnMediaUnderParent() throws {
        // Given
        // The screen shows media time 1.5 at sequence time 0.5, and the clip, from its `in` 0.2 there, 0.2.
        let sut = TrackPlanner()
        let trackData = data(atMediaTime: 0.2)
        let time = try plan(connected: #"""
            { "media": "/abs/screen.mp4", "parent": "screen", "position": [0, 0], "in": 0.2, "at": [1.5, 2.5], "track": \#(trackData) }
            """#)

        // When
        let plan = try sut.plan(time)

        // Then
        let track = try #require(plan.clips[0])
        let clock = try #require(time.clips[0].mediaClock)
        #expect(track.clock == clock)
        #expect(clock.mediaTime(atSequenceTime: time.clips[0].instant) == 0.2)
        #expect(track.track.mediaTime == 0.2)
    }

    @Test(
        "track stops where there is nothing to follow",
        arguments: untrackable
    )
    func refusesUntrackable(
        document: String,
        message: String
    ) throws {
        // Given
        let sut = TrackPlanner()
        let time = try Fixture.planner.plan(document: Fixture.json(document))

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(time) }
        #expect(error?.description == message)
    }

    // MARK: - Private
    // The track data the fake tracker gives for `total` followed from the frame at `time`, whose `time` it names.
    private func data(
        atMediaTime time: Double,
        followed: ClosedRange<Double>? = nil,
        over range: ClosedRange<Double> = -Double.infinity...Double.infinity
    ) -> String {
        TrackerTable(
            frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes],
            followed: followed.map { ["/abs/screen.mp4": $0] } ?? [:],
            drift: Point(x: 0, y: 10)
        )
        .data(Quad(total), in: "/abs/screen.mp4", atMediaTime: time, over: range)
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

    private func moved(
        _ rectangle: Rectangle,
        down distance: Double
    ) -> Rectangle {
        Rectangle(x: rectangle.x, y: rectangle.y + distance, width: rectangle.width, height: rectangle.height)
    }
}
