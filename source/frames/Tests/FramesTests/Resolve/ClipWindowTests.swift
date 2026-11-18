//
//  ClipWindowTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("Clip Window Tests")
struct ClipWindowTests {
    // MARK: - Property
    private let sut = Fixture.planner

    // A clip at speed 2 between two solids, brought in and out by one-second transitions: edit [2, 5), drawn [1.5, 5.5).
    private let fastClip = ##"""
        { "solid": "#000000", "duration": 2 },
        { "id": "run", "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "transition": { "preset": "frames/flash", "seconds": 1 }, "connected": [ %@ ] },
        { "solid": "#FFFFFF", "duration": 2, "transition": { "preset": "frames/flash", "seconds": 1 } }
        """##

    // MARK: - Initializer
    // MARK: - Test
    @Test("a connected clip's at is on its storyline clip's clip time")
    func placesConnectedClipOnClipTime() throws {
        // Given
        let document = try sequence(connected: #"{ "at": [4, 6], "title": "a", "style": "subtitle" }"#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].window == TimeRange(start: 3, end: 4))
        #expect(plan.clips[0].clock == plan.storyline[1].map)
    }

    @Test("under a clip at speed 2, [2, 6] ends at clip second 6, and 2 ends when the media does")
    func tellsWindowFormsApart() throws {
        // Given
        let document = try sequence(connected: #"""
            { "at": [2, 6], "media": "/abs/short.mp4" }, { "at": 2, "media": "/abs/short.mp4" }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].window == TimeRange(start: 2, end: 4))
        #expect(plan.clips[1].window == TimeRange(start: 2, end: 6))
    }

    @Test("a sound connected to a clip at speed 2 plays its full length at its own speed")
    func playsSoundAtItsOwnSpeed() throws {
        // Given
        let document = try sequence(connected: #"{ "at": 2, "media": "/abs/ding.wav" }"#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].window == TimeRange(start: 2, end: 3.5))
        #expect(plan.clips[0].mediaClock?.mediaTime(atSequenceTime: 3) == 1)
        #expect(plan.clips[0].lane == nil)
    }

    @Test("a connected clip without at spans its storyline clip's edit range, whether it has a parent or not")
    func spansStorylineClipWithoutAt() throws {
        // Given
        let document = try sequence(connected: #"""
            { "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "parent": "run" }, { "title": "a", "style": "subtitle" }, { "title": "b", "style": "subtitle", "parent": "run", "position": [0, 0] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips.map(\.window) == [
            TimeRange(start: 2, end: 5),
            TimeRange(start: 2, end: 5),
            TimeRange(start: 2, end: 5)
        ])
        #expect(plan.clips.map(\.parent) == [.storyline(index: 1, id: "run"), nil, .storyline(index: 1, id: "run")])
    }

    @Test("a connected clip whose window starts at its storyline clip's in starts at the edit point, inside the transition")
    func startsWindowAtEditPoint() throws {
        // Given
        let document = try sequence(connected: #"{ "at": [2, 4], "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "parent": "run" }"#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].visible == TimeRange(start: 2, end: 3))
        #expect(plan.storyline[1].drawn.start == 1.5)
    }

    @Test("a connected clip parented to its storyline clip is visible over its window cut to the sequence, past the drawn range")
    func cutsParentedClipToSequence() throws {
        // Given
        let document = try sequence(connected: #"{ "at": [0, 20], "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "parent": "run" }"#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].window == TimeRange(start: 1, end: 11))
        #expect(plan.clips[0].visible == TimeRange(start: 1, end: 7))
        #expect(plan.clips[0].storyline == 1)
    }

    @Test("an unparented connected clip plays its whole window across edit points, and only the end of the sequence cuts it")
    func playsUnparentedClipAcrossEditPoints() throws {
        // Given
        let document = try sequence(connected: #"{ "at": [0, 20], "title": "a", "style": "subtitle" }"#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].visible == TimeRange(start: 1, end: 7))
    }

    @Test("a connected clip with a picture whose window does not meet the sequence stops")
    func refusesNeverVisibleClip() throws {
        // Given
        let document = try sequence(connected: #"{ "at": [12, 20], "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10] }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error?.description == "storyline[1]#run.connected[0] (rect): never visible, since its window [7, 11) does not meet [0, 7)")
    }

    @Test("a connected sound plays its window across transitions, but one whose start lies outside the drawn range stops")
    func anchorsConnectedSoundByStart() throws {
        // Given
        let across = try sequence(connected: #"{ "at": [8, 14], "media": "/abs/ding.wav" }"#)
        let outside = try sequence(connected: #"{ "at": [12, 14], "media": "/abs/ding.wav" }"#)

        // When
        let plan = try sut.plan(document: across)

        // Then
        #expect(plan.clips[0].visible == TimeRange(start: 5, end: 7))
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: outside) }
        #expect(error?.description == "storyline[1]#run.connected[0] (audio): starts at 7, outside its storyline clip's drawn range [1.5, 5.5)")
    }

    @Test("a sequence clip's at is on sequence time, and a sequence clip without at spans the whole sequence")
    func placesSequenceClips() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 4 } ], "clips": [
              { "at": [1, 3], "title": "a", "style": "headline" },
              { "media": "/abs/bgm.m4a" },
              { "at": 3, "media": "/abs/ding.wav" }
            ] }
            """##)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips.map(\.window) == [TimeRange(start: 1, end: 3), TimeRange(start: 0, end: 4), TimeRange(start: 3, end: 4.5)])
        #expect(plan.clips.map(\.visible) == [TimeRange(start: 1, end: 3), TimeRange(start: 0, end: 4), TimeRange(start: 3, end: 4)])
        #expect(plan.clips.allSatisfy { $0.storyline == nil && $0.parent == nil && $0.clock == .sequence })
    }

    @Test(
        "a sequence clip that starts at or after the end of the sequence stops, and so does one that ends before it starts",
        arguments: [
            (#"{ "at": [4, 6], "title": "a", "style": "headline" }"#, "clips[0] (title): starts at 4, at or after the end of the sequence at 4"),
            (#"{ "at": 5, "media": "/abs/ding.wav" }"#, "clips[0] (audio): starts at 5, at or after the end of the sequence at 4"),
            (#"{ "at": [-3, -1], "title": "a", "style": "headline" }"#, "clips[0] (title): never visible, since its window [-3, -1) does not meet [0, 4)"),
            (#"{ "at": [-3, 0], "media": "/abs/ding.wav" }"#, "clips[0] (audio): never plays, since its window [-3, 0) ends before the sequence starts")
        ]
    )
    func refusesSequenceClipOutsideSequence(
        clip: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(##"{ "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 4 } ], "clips": [ \##(clip) ] }"##)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error?.description == message)
    }

    @Test("a window that ends before it starts stops")
    func refusesEmptyWindow() throws {
        // Given
        let document = try sequence(connected: #"{ "at": [6, 2], "title": "a", "style": "subtitle" }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error?.description == "storyline[1]#run.connected[0].at (title): the window [6, 2] ends before it starts")
    }

    @Test("a connected clip's keyframes are on its storyline clip's clip time, and a sequence clip's on sequence time")
    func mapsClipKeyframes() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "solid": "#000000", "duration": 2 },
              { "id": "run", "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2,
                "connected": [ { "at": [2, 8], "shape": "rect", "stroke": { "width": 8 }, "parent": "run", "keyframes": [ { "at": 4, "area": { "text": "A" } }, { "at": 6, "area": { "text": "B" } } ] } ] }
            ], "clips": [ { "at": [0, 5], "media": "/abs/log.png", "keyframes": [ { "at": 1, "scale": 1 }, { "at": 2, "scale": 2 } ] } ] }
            """##)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].keyframes.map(\.at) == [3, 4])
        #expect(plan.clips[1].keyframes.map(\.at) == [1, 2])
    }

    @Test("every clip with a picture has lane 1 unless it says otherwise, and lane 0 stops")
    func givesLanes() throws {
        // Given
        let document = try sequence(connected: #"""
            { "title": "a", "style": "subtitle" }, { "title": "b", "style": "subtitle", "lane": -2 }
            """#)
        let zero = try sequence(connected: #"{ "title": "a", "style": "subtitle", "lane": 0 }"#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips.map(\.lane) == [1, -2])
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: zero) }
        #expect(error?.description == "storyline[1]#run.connected[0].lane (title): lane 0 is the storyline. A clip takes a lane above or below it")
    }

    @Test("a shape or adjustment placed by an area has a parent only when it names one")
    func parentsOnlyByName() throws {
        // Given
        let document = try sequence(connected: #"""
            { "adjust": "frames/vivid", "mask": { "shape": "rect", "area": [0, 0, 10, 10] } }, { "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10] }, { "adjust": "frames/vivid", "mask": { "shape": "rect", "area": [0, 0, 10, 10] }, "parent": "run" }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips.map(\.parent) == [nil, nil, .storyline(index: 1, id: "run")])
    }

    // MARK: - Private
    private func sequence(connected: String) throws -> JSONValue {
        let storyline = fastClip.replacingOccurrences(of: "%@", with: connected)
        return try Fixture.json(#"{ "kind": "sequence", "storyline": [ \#(storyline) ] }"#)
    }
}
