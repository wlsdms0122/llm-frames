//
//  TrackFormTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

// `/abs/screen.mp4` has a frame every 0.1 media seconds over 4 seconds. Its storyline clip plays media [1, 3) over the
// edit range [0, 2), and a connected clip's `at` is in that media time, so at sequence time t it shows media time t + 1.
@Suite("TrackForm Tests")
struct TrackFormTests {
    // MARK: - Property
    private static let target = "[[100, 100], [300, 100], [300, 140], [100, 140]]"

    private let checker = KeyChecker(mediaKinds: Fixture.mediaKinds)
    private let total = Rectangle(x: 100, y: 100, width: 200, height: 40)

    // MARK: - Initializer
    // MARK: - Test
    @Test("track data, a time and its frames, passes the key check")
    func takesTrackData() throws {
        // Given
        let document = try document(track: #"{ "time": 1, "frames": [ { "time": 1, "quad": \#(Self.target) } ] }"#)

        // When, Then
        try checker.check(document: document)
    }

    @Test(
        "track data without a time or frames, with another key, or another value stops where it is written",
        arguments: [
            (
                "true",
                "storyline[0]#screen.connected[0].track (rect): expected an object (track), found true"
            ),
            (
                #"{ "frames": [ { "time": 1, "quad": \#(target) } ] }"#,
                #"storyline[0]#screen.connected[0].track (track): missing key "time". A track is track data {time, frames}, as frames track prints it, or a request {"tool": "<pack>/<name>", ...} for a tool that fills it"#
            ),
            (
                #"{ "time": 1 }"#,
                #"storyline[0]#screen.connected[0].track (track): missing key "frames". A track is track data {time, frames}, as frames track prints it, or a request {"tool": "<pack>/<name>", ...} for a tool that fills it"#
            ),
            (
                #"{ "time": 1, "frames": [ { "time": 1, "quad": \#(target) } ], "speed": 2 }"#,
                #"storyline[0]#screen.connected[0].track (track): unknown key "speed". Allowed: time, frames. A track is track data {time, frames}, as frames track prints it, or a request {"tool": "<pack>/<name>", ...} for a tool that fills it"#
            ),
            (
                #"{ "time": 1, "frames": [ { "time": 1 } ] }"#,
                #"storyline[0]#screen.connected[0].track.frames[0] (track data frame): missing key "quad""#
            ),
            (
                #"{ "time": 1, "frames": [ { "time": 1, "quad": [[100, 100], [300, 100], [300, 140]] } ] }"#,
                "storyline[0]#screen.connected[0].track.frames[0].quad (track data frame): expected a list of four points [x, y] of numbers, found a list of 3"
            ),
            (
                #"{ "time": 1, "frames": [ { "time": 1, "quad": [[100, 100], [300, 100], [300, 140], [100, "a"]] } ] }"#,
                #"storyline[0]#screen.connected[0].track.frames[0].quad[3][1] (track data frame): expected a number, found "a""#
            ),
            (
                #"{ "time": 1, "frames": [ { "time": 1, "quad": \#(target), "motion": [] } ] }"#,
                #"storyline[0]#screen.connected[0].track.frames[0] (track data frame): unknown key "motion". Allowed: time, quad"#
            )
        ]
    )
    func refusesTrackObject(
        track: String,
        message: String
    ) throws {
        // Given
        let document = try document(track: track)

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("the reader takes the time and the frames of track data")
    func readsTrackData() throws {
        // Given
        let reader = SequenceReader()

        // When
        let clip = try clip(track: #"{ "time": 1.5, "frames": [ { "time": 1.5, "quad": \#(Self.target) } ] }"#, reader: reader)

        // Then
        #expect(clip.track == TrackData(time: 1.5, frames: [TrackDataFrame(time: 1.5, quad: Quad(total))]))
    }

    @Test(
        "track data whose time names no frame of the tracked media stops, naming the time",
        arguments: [(-0.5, "-0.5"), (4, "4"), (7, "7")]
    )
    func refusesTimeOutside(
        mediaTime: Double,
        written: String
    ) throws {
        // Given
        let sut = TrackPlanner()
        let time = try plan(#"{ "kind": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "at": [1, 3], "track": { "time": \#(written), "frames": [ { "time": 1, "quad": \#(Self.target) } ] } }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try sut.plan(time)
        }
        #expect(error?.description == "storyline[0]#screen.connected[0].track.time (rect): media time \(written) names no frame of the tracked media")
    }

    @Test("a connected clip whose instant shows a frame the track data does not name stops, naming that media time")
    func refusesUnfollowedInstant() throws {
        // Given
        let sut = TrackPlanner()
        let tracker = TrackerTable(frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes], followed: ["/abs/screen.mp4": 1.4...2])
        let trackData = tracker.data(Quad(total), in: "/abs/screen.mp4", atMediaTime: 1.5)
        let time = try plan(#"{ "kind": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "at": [1, 3], "track": \#(trackData) }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try sut.plan(time)
        }
        #expect(error?.description == #"""
            storyline[0]#screen.connected[0].track (rect): the clip's instant shows media time 1, a frame the track data \#
            does not name, so its window holds none
            """#)
    }

    @Test("track data gives the track: each frame at the timestamp of the frame it names, and the target the quad at time")
    func followsTrackData() throws {
        // Given
        let sut = TrackPlanner()
        let time = try plan(#"""
            { "kind": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "at": [1, 3],
              "track": { "time": 1.12, "frames": [
                { "time": 1.01, "quad": [[100, 100], [300, 100], [300, 140], [100, 140]] },
                { "time": 1.13, "quad": [[102, 100], [302, 100], [302, 140], [102, 140]] },
                { "time": 1.2, "quad": [[104, 101], [304, 101], [304, 141], [104, 141]] } ] } }
            """#)

        // When
        let plan = try sut.plan(time)

        // Then
        let track = try #require(plan.clips[0]?.track)
        #expect(track.mediaTime == 1.1)
        #expect(track.target == Quad(moved(total, right: 2)))
        #expect(track.samples.map(\.time) == [1, 1.1, 1.2])
        #expect(track.samples[1].motion == TrackMotion(from: track.target, to: track.target))
        // Sequence time 0.3 is the first to show media time 1.3, which the data does not name.
        #expect(plan.time.clips[0].visible.start == 0)
        #expect(abs(plan.time.clips[0].visible.end - 0.3) < 1e-9)
    }

    @Test(
        "track data whose quads or times are wrong stops, naming the frame or the track",
        arguments: [
            (
                #"[ { "time": 1, "quad": \#(target) }, { "time": 4.2, "quad": \#(target) } ]"#,
                "storyline[0]#screen.connected[0].track.frames[1] (rect): the frame's time names no frame of the tracked media"
            ),
            (
                #"[ { "time": 1, "quad": \#(target) }, { "time": 1.1, "quad": [[100, 100], [300, 100], [200, 100], [100, 140]] } ]"#,
                "storyline[0]#screen.connected[0].track.frames[1] (rect): the quad is not strictly convex"
            ),
            (
                #"[ { "time": 1, "quad": \#(target) }, { "time": 1.1, "quad": [[100, 140], [300, 140], [300, 100], [100, 100]] } ]"#,
                #"storyline[0]#screen.connected[0].track.frames[1] (rect): the quad runs the other way round than the quad of the frame "time" names"#
            ),
            (
                #"[ { "time": 1.1, "quad": \#(target) }, { "time": 1, "quad": \#(target) } ]"#,
                "storyline[0]#screen.connected[0].track.frames[1] (rect): the frames are not in time order"
            ),
            (
                #"[ { "time": 1, "quad": \#(target) }, { "time": 1.05, "quad": \#(target) } ]"#,
                "storyline[0]#screen.connected[0].track.frames[1] (rect): two frames name one media frame"
            ),
            (
                #"[ { "time": 1, "quad": \#(target) }, { "time": 1.2, "quad": \#(target) } ]"#,
                "storyline[0]#screen.connected[0].track.frames[1] (rect): a media frame between this frame and the one before it has no frame of the data"
            ),
            (
                #"[ { "time": 1.1, "quad": \#(target) }, { "time": 1.2, "quad": \#(target) } ]"#,
                #"storyline[0]#screen.connected[0].track (rect): "time" names no frame of "frames", so the data gives no target"#
            )
        ]
    )
    func refusesTrackData(
        frames: String,
        message: String
    ) throws {
        // Given
        let sut = TrackPlanner()
        let time = try plan(#"{ "kind": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "at": [1, 3], "track": { "time": 1, "frames": \#(frames) } }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try sut.plan(time)
        }
        #expect(error?.description == message)
    }

    // MARK: - Private
    private func document(track: String) throws -> JSONValue {
        try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/run.mp4", "connected": [
                { "kind": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "track": \#(track) } ] } ] }
            """#)
    }

    private func clip(
        track: String,
        reader: SequenceReader
    ) throws -> Clip {
        reader.sequence(from: try document(track: track)).storyline[0].connected[0]
    }

    private func plan(_ connected: String) throws -> TimePlan {
        try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [
                { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "in": 1, "out": 3, "connected": [ \#(connected) ] } ] }
            """#))
    }

    private func moved(
        _ rectangle: Rectangle,
        right offset: Double
    ) -> Rectangle {
        Rectangle(x: rectangle.x + offset, y: rectangle.y, width: rectangle.width, height: rectangle.height)
    }
}
