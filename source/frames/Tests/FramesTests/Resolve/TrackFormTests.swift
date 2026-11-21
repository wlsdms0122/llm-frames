//
//  TrackFormTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

// `/abs/screen.mp4` has a frame every 0.1 media seconds over 4 seconds. Its storyline clip plays media [1, 3) over the
// edit range [0, 2), and a connected clip's `at` is in that media time, so at sequence time t it shows media time t + 1. The fake tracker moves the target
// 10 pixels down per media second from the frame it is given.
@Suite("TrackForm Tests")
struct TrackFormTests {
    // MARK: - Property
    private static let target = "[[100, 100], [300, 100], [300, 140], [100, 140]]"

    private let checker = KeyChecker(mediaKinds: Fixture.mediaKinds)
    private let total = Rectangle(x: 100, y: 100, width: 200, height: 40)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a track object takes a time and at most one of an area and track data",
        arguments: [
            #"{ "time": 1 }"#,
            #"{ "time": 1, "area": [100, 100, 200, 40] }"#,
            #"{ "time": 1, "area": { "text": "Total" } }"#,
            #"{ "time": 1, "frames": [ { "time": 1, "quad": \#(target) } ] }"#
        ]
    )
    func takesTrackObject(track: String) throws {
        // Given
        let document = try document(track: track)

        // When, Then
        try checker.check(document: document)
    }

    @Test(
        "a track object without a time, with both an area and track data, or with another key stops where it is written",
        arguments: [
            (
                #"{ "area": [100, 100, 200, 40] }"#,
                #"storyline[0]#screen.connected[0].track (track): missing key "time""#
            ),
            (
                #"{ "time": 1, "area": [100, 100, 200, 40], "frames": [ { "time": 1, "quad": \#(target) } ] }"#,
                #"storyline[0]#screen.connected[0].track (track): takes only one of "area", "frames""#
            ),
            (
                #"{ "time": 1, "speed": 2 }"#,
                #"storyline[0]#screen.connected[0].track (track): unknown key "speed". Allowed: time, area, frames"#
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

    @Test("the reader takes the time of a track object and beside it the own geometry, an area or track data")
    func readsTrackObject() throws {
        // Given
        let reader = SequenceReader()
        let quad = Quad(total)

        // When
        let own = try clip(track: #"{ "time": 1.5 }"#, reader: reader)
        let area = try clip(track: #"{ "time": 1.5, "area": [100, 100, 200, 40] }"#, reader: reader)
        let data = try clip(track: #"{ "time": 1.5, "frames": [ { "time": 1.5, "quad": \#(Self.target) } ] }"#, reader: reader)

        // Then
        #expect(own.track == .own(time: 1.5))
        #expect(area.track == .area(.rectangle(total), time: 1.5))
        #expect(data.track == .data(time: 1.5, frames: [TrackDataFrame(time: 1.5, quad: quad)]))
    }

    @Test("true written as an object with a time follows the clip's own geometry from the frame the time names")
    func followsOwnFromTime() throws {
        // Given
        let sut = planner()
        let time = try plan(#"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3], "track": { "time": 1.54 } }"#)

        // When
        let plan = try sut.plan(time, storylineCrops: [nil], storylineMasks: [nil], crops: [nil], areas: [.value(.found(found(total, at: 1)))], masks: [nil], cornerPins: time.clips.map { _ in nil })

        // Then
        let track = try #require(plan.clips[0]?.track)
        #expect(track.mediaTime == 1.5)
        #expect(track.target == Quad(total))
        #expect(track.samples.first?.time == 1)
        #expect(track.motion(atMediaTime: 1.5) == TrackMotion(from: Quad(total), to: Quad(total)))
        #expect(track.samples.first?.quad == Quad(moved(total, down: -5)))
    }

    @Test("an area written in a track object with a time is found on the frame the time names")
    func followsAreaFromTime() throws {
        // Given
        let sut = planner()
        let time = try plan(#"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "at": [1, 3], "track": { "time": 2, "area": { "text": "Total" } } }"#)

        // When
        let plan = try sut.plan(time, storylineCrops: [nil], storylineMasks: [nil], crops: [nil], areas: [nil], masks: [nil], cornerPins: time.clips.map { _ in nil })

        // Then
        let track = try #require(plan.clips[0]?.track)
        #expect(track.mediaTime == 2)
        #expect(track.target == Quad(total))
        #expect(track.samples.first?.quad == Quad(moved(total, down: -10)))
    }

    @Test("a track object with a time stops where the geometry it follows is keyframed")
    func refusesKeyframedOwnFromTime() throws {
        // Given
        let sut = planner()
        let time = try plan(#"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "at": [1, 3], "track": { "time": 1 }, "keyframes": [ { "at": 0, "area": [100, 100, 200, 40] }, { "at": 1, "area": [100, 120, 200, 40] } ] }"#)
        let areas: [PropertyValue<FoundArea>?] = [.keyframes([
            PropertyKeyframe(index: 0, at: 0, value: found(total, at: 1), ease: .linear),
            PropertyKeyframe(index: 1, at: 1, value: found(moved(total, down: 20), at: 2), ease: .linear)
        ])]

        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try sut.plan(time, storylineCrops: [nil], storylineMasks: [nil], crops: [nil], areas: areas.map { $0?.map(AreaValue.found) }, masks: [nil], cornerPins: time.clips.map { _ in nil })
        }
        #expect(error?.description == #"""
            storyline[0]#screen.connected[0].track (rect): the geometry "track" follows is keyframed, and a keyframe's \#
            value is where it is at its own time, so none is written on the frame "time" names
            """#)
    }

    @Test(
        "a track object whose time names no frame of the tracked media stops, naming the time",
        arguments: [(-0.5, "-0.5"), (4, "4"), (7, "7")]
    )
    func refusesTimeOutside(
        mediaTime: Double,
        written: String
    ) throws {
        // Given
        let sut = planner()
        let time = try plan(#"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "at": [1, 3], "track": { "time": \#(written), "area": [100, 100, 200, 40] } }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try sut.plan(time, storylineCrops: [nil], storylineMasks: [nil], crops: [nil], areas: [nil], masks: [nil], cornerPins: time.clips.map { _ in nil })
        }
        #expect(error?.description == "storyline[0]#screen.connected[0].track.time (rect): media time \(written) names no frame of the tracked media")
    }

    @Test("a connected clip whose instant shows a frame the track named by time does not follow stops, naming that media time")
    func refusesUnfollowedInstant() throws {
        // Given
        let sut = planner(followed: 1.4...2)
        let time = try plan(#"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "at": [1, 3], "track": { "time": 1.5, "area": [100, 100, 200, 40] } }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try sut.plan(time, storylineCrops: [nil], storylineMasks: [nil], crops: [nil], areas: [nil], masks: [nil], cornerPins: time.clips.map { _ in nil })
        }
        #expect(error?.description == #"""
            storyline[0]#screen.connected[0].track (rect): the clip's instant shows media time 1, a frame the track does \#
            not follow, so its window holds none
            """#)
    }

    @Test("track data gives the track: each frame at the timestamp of the frame it names, the target the quad at time, and no tracker call")
    func followsTrackData() throws {
        // Given
        // The tracker follows nothing, so a frame followed comes from the data.
        let sut = planner(followed: 10...11)
        let time = try plan(#"""
            { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "at": [1, 3],
              "track": { "time": 1.12, "frames": [
                { "time": 1.01, "quad": [[100, 100], [300, 100], [300, 140], [100, 140]] },
                { "time": 1.13, "quad": [[102, 100], [302, 100], [302, 140], [102, 140]] },
                { "time": 1.2, "quad": [[104, 101], [304, 101], [304, 141], [104, 141]] } ] } }
            """#)

        // When
        let plan = try sut.plan(time, storylineCrops: [nil], storylineMasks: [nil], crops: [nil], areas: [nil], masks: [nil], cornerPins: time.clips.map { _ in nil })

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
        let sut = planner()
        let time = try plan(#"{ "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "at": [1, 3], "track": { "time": 1, "frames": \#(frames) } }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try sut.plan(time, storylineCrops: [nil], storylineMasks: [nil], crops: [nil], areas: [nil], masks: [nil], cornerPins: time.clips.map { _ in nil })
        }
        #expect(error?.description == message)
    }

    // MARK: - Private
    private func document(track: String) throws -> JSONValue {
        try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/run.mp4", "connected": [
                { "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": [0, 0, 10, 10], "track": \#(track) } ] } ] }
            """#)
    }

    private func clip(
        track: String,
        reader: SequenceReader
    ) throws -> Clip {
        reader.sequence(from: try document(track: track)).storyline[0].connected[0]
    }

    private func planner(followed: ClosedRange<Double>? = nil) -> TrackPlanner {
        TrackPlanner(
            tracker: TrackerTable(
                frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes],
                followed: followed.map { ["/abs/screen.mp4": $0] } ?? [:],
                drift: Point(x: 0, y: 10)
            ),
            ocr: OCRTable(file: "/abs/screen.mp4", lines: [RecognisedLine(text: "Total", rectangle: total)]),
            languages: nil
        )
    }

    private func plan(_ connected: String) throws -> TimePlan {
        try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [
                { "id": "screen", "media": "/abs/screen.mp4", "in": 1, "out": 3, "connected": [ \#(connected) ] } ] }
            """#))
    }

    private func found(
        _ target: Rectangle,
        at mediaTime: Double
    ) -> FoundArea {
        FoundArea(rectangle: target, target: target, mediaTime: mediaTime, lines: [])
    }

    private func moved(
        _ rectangle: Rectangle,
        down distance: Double = 0,
        right offset: Double = 0
    ) -> Rectangle {
        Rectangle(x: rectangle.x + offset, y: rectangle.y + distance, width: rectangle.width, height: rectangle.height)
    }
}
