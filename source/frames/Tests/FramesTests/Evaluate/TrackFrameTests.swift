//
//  TrackFrameTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

// `/abs/screen.mp4` has a frame every 0.1 media seconds. Its storyline clip plays media [1, 3) over the edit range
// [0, 2), and a connected clip's `at` is in that media time, so at sequence time t it shows media time t + 1: the
// instant 0 shows media 1, and time 0.5 shows media 1.5, the frame the track data's time 1.5 names. The track data is
// what a fake tracker gives that moves the target 10 pixels down per media second from the frame it is given, so the
// motion at media 1 moves 5 pixels up.
@Suite("TrackFrame Tests")
struct TrackFrameTests {
    // MARK: - Property
    private let sut = Evaluator()
    private let tracker = TrackerTable(frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes], drift: Point(x: 0, y: 10))
    private var track: String {
        tracker.data(Quad(Rectangle(x: 100, y: 100, width: 200, height: 40)), in: "/abs/screen.mp4", atMediaTime: 1.5)
    }

    // MARK: - Initializer
    // MARK: - Test
    @Test("a static area written as numbers under a track's time is true on the frame the time names and is written as its value")
    func keepsWrittenStaticOnTrackFrame() throws {
        // Given
        let sequence = try resolved(#"""
            { "id": "tracked", "kind": "rect", "fill": "#FFFFFF", "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3], "track": \#(track) },
            { "id": "still", "kind": "rect", "fill": "#FFFFFF", "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3] }
            """#)

        // When
        let text = ResolvedDocumentWriter().write(sequence)
        let read = try ResolvedDocumentReader().read(text)
        let onTrackFrame = try boxes(in: sut.displayList(of: read, at: 0.5))
        let atInstant = try boxes(in: sut.displayList(of: read, at: 0))

        // Then
        #expect(read == sequence)
        #expect(text.contains(#""area": [100, 100, 200, 40]"#))
        #expect(onTrackFrame.tracked == onTrackFrame.still)
        #expect(abs(atInstant.tracked.y - (atInstant.still.y - 5 * atInstant.scale)) < 1e-9)
        #expect(atInstant.tracked.x == atInstant.still.x)
    }

    @Test("a tracked area's keyframes are brought back through the motion at their own times, where a static area is true on the track's frame")
    func bringsKeyframedAreaBack() throws {
        // Given
        let sequence = try resolved(#"""
            { "id": "static", "kind": "rect", "fill": "#FFFFFF", "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3], "track": \#(track) },
            { "id": "keyed", "kind": "rect", "fill": "#FFFFFF", "parent": "screen", "at": [1, 3], "track": \#(track),
              "keyframes": [ { "at": 1, "area": [100, 100, 200, 40] }, { "at": 2, "area": [100, 100, 200, 40] } ] },
            { "id": "still", "kind": "rect", "fill": "#FFFFFF", "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3] }
            """#)

        // When
        let read = try ResolvedDocumentReader().read(ResolvedDocumentWriter().write(sequence))
        let lists = [0, 0.5, 1].map { time in sut.displayList(of: read, at: time) }

        // Then
        #expect(read == sequence)
        #expect(area(of: "static", in: read) == .onTrackFrame(.rectangle(Rectangle(x: 100, y: 100, width: 200, height: 40))))
        #expect(area(of: "keyed", in: read)?.keyframeTimes == [0, 1])
        // Each keyframe is drawn where it is written at its own time, and the static area only on the track's frame,
        // media 1.5, five pixels below where it is drawn at media 1 and five above where it is drawn at media 2.
        for (list, offset) in zip(lists, [-5.0, 0, 5]) {
            let still = try rectangle(of: "still", in: list)
            let scale = try #require(list.items.first { $0.origin?.id == "still" }).transform.d
            #expect(isClose(try rectangle(of: "keyed", in: list), still))
            #expect(abs(try rectangle(of: "static", in: list).y - (still.y + offset * scale)) < 1e-9)
        }
    }

    @Test("a mask with keyframes keeps each geometry leaf written without keyframes true on the track's frame, and a leaf one keyframe writes at its time")
    func keepsStaticMaskLeavesOnTrackFrame() throws {
        // Given
        let sequence = try resolved(#"""
            { "id": "tracked", "kind": "rect", "fill": "#FFFFFF", "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3], "track": \#(track),
              "mask": [ { "kind": "rect", "area": [110, 110, 50, 20] } ], "keyframes": [ { "at": 1, "mask": [ { "radius": 4 } ] } ] },
            { "id": "still", "kind": "rect", "fill": "#FFFFFF", "parent": "screen", "area": [100, 100, 200, 40], "at": [1, 3] }
            """#)

        // When
        let read = try ResolvedDocumentReader().read(ResolvedDocumentWriter().write(sequence))

        // Then
        let clip = try #require(read.clips.first { $0.id == "tracked" })
        guard case let .rect(.area(area), radius) = clip.composite?.mask?.first?.geometry else {
            Issue.record("the tracked clip's mask is not a rect placed by its area")
            return
        }
        #expect(read == sequence)
        #expect(area == .onTrackFrame(.rectangle(Rectangle(x: 110, y: 110, width: 50, height: 20))))
        #expect(radius.keyframeTimes.count == 1)
    }

    @Test("a tracked path keeps each vertex leaf written without keyframes true on the track's frame, a point on an area included, and a keyframed tangent at its keyframes")
    func keepsStaticPathLeavesOnTrackFrame() throws {
        // Given
        let sequence = try resolved(#"""
            { "id": "tracked", "kind": "path", "stroke": { "width": 4 }, "parent": "screen", "at": [1, 3], "track": \#(track),
              "points": [[100, 100], { "vertex": [300, 100], "inTangent": [0, 20] }, { "vertex": { "area": [100, 100, 200, 40], "point": "left" } }],
              "keyframes": [ { "at": 1, "points": [{ "outTangent": [10, 0] }, {}, {}] }, { "at": 2, "points": [{ "outTangent": [20, 0] }, {}, {}] } ] }
            """#)

        // When
        let read = try ResolvedDocumentReader().read(ResolvedDocumentWriter().write(sequence))

        // Then
        let clip = try #require(read.clips.first { $0.id == "tracked" })
        guard case let .picture(.shape(shape), _, _) = clip.content, case let .points(vertices, _, _) = shape.geometry else {
            Issue.record("the tracked clip is a path")
            return
        }
        #expect(read == sequence)
        #expect(vertices[0].vertex == .onTrackFrame(.point(Point(x: 100, y: 100))))
        #expect(vertices[0].inTangent == .onTrackFrame(Point(x: 0, y: 0)))
        #expect(vertices[0].outTangent.keyframeTimes.count == 2)
        #expect(vertices[1].inTangent == .onTrackFrame(Point(x: 0, y: 20)))
        #expect(vertices[2].vertex == .onTrackFrame(.point(Point(x: 100, y: 120))))
        #expect(vertices[2].outTangent == .onTrackFrame(Point(x: 0, y: 0)))
    }

    @Test("a corner pin tracked where every quad is a similarity image of the target is drawn as written, inside the track's motion")
    func drawsTrackedCornerPinAsWritten() throws {
        // Given
        let pin = Quad(
            topLeft: Point(x: 100, y: 100),
            topRight: Point(x: 500, y: 120),
            bottomRight: Point(x: 480, y: 400),
            bottomLeft: Point(x: 120, y: 380)
        )
        let track = tracker.data(pin, in: "/abs/screen.mp4", atMediaTime: 1)
        let sequence = try resolved(#"""
            { "id": "tracked", "kind": "media", "media": "/abs/card.png", "width": 300, "parent": "screen", "at": [1, 3], "cornerPin": [[100, 100], [500, 120], [480, 400], [120, 380]], "track": \#(track) },
            { "id": "still", "kind": "media", "media": "/abs/card.png", "width": 300, "parent": "screen", "at": [1, 3], "cornerPin": [[100, 100], [500, 120], [480, 400], [120, 380]] }
            """#)

        // When
        let list = sut.displayList(of: sequence, at: 0.5)

        // Then
        // The track's frame is media 1, the one the instant shows, and at media 1.5 the target has moved 5 pixels down.
        let tracked = try #require(list.items.first { $0.origin?.id == "tracked" })
        let still = try #require(list.items.first { $0.origin?.id == "still" })
        guard case let .picture(trackedPicture) = tracked.content, case let .picture(stillPicture) = still.content else {
            Issue.record("a group is not a picture")
            return
        }
        let trackedPin = try #require(trackedPicture.cornerPin)
        let stillPin = try #require(stillPicture.cornerPin)
        #expect(zip(trackedPin.corners, stillPin.corners).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 })
        #expect(tracked.transform.tx == still.transform.tx)
        #expect(abs(tracked.transform.ty - (still.transform.ty + 5 * still.transform.d)) < 1e-9)
    }

    // MARK: - Private
    private func resolved(_ connected: String) throws -> ResolvedSequence {
        let document = #"""
            { "kind": "sequence", "storyline": [
                { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "in": 1, "out": 3, "connected": [ \#(connected) ] } ] }
            """#

        return try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    // The rectangle of each clip's path carried by its item's transform to output pixels, and the vertical scale of
    // the still clip's transform, which is its parent's.
    private func boxes(in list: DisplayList) throws -> (tracked: Rectangle, still: Rectangle, scale: Double) {
        let still = try #require(list.items.first { $0.origin?.id == "still" })

        return (try rectangle(of: "tracked", in: list), try rectangle(of: "still", in: list), still.transform.d)
    }

    // The rectangle of a clip's path carried by its item's transform to output pixels.
    private func rectangle(
        of id: String,
        in list: DisplayList
    ) throws -> Rectangle {
        let item = try #require(list.items.first { $0.origin?.id == id })
        let rectangle: Rectangle? = if case let .path(path) = item.content, case let .rect(rectangle, _) = path.geometry {
            rectangle
        } else {
            nil
        }

        return Rectangle(bounding: item.transform.apply(toCornersOf: try #require(rectangle)))
    }

    private func isClose(
        _ rectangle: Rectangle,
        _ other: Rectangle
    ) -> Bool {
        [rectangle.x - other.x, rectangle.y - other.y, rectangle.width - other.width, rectangle.height - other.height]
            .allSatisfy { abs($0) < 1e-9 }
    }

    // The area of a shape placed by its area in a resolved sequence, nil for any other clip.
    private func area(
        of id: String,
        in sequence: ResolvedSequence
    ) -> FollowedValue<GeometryArea>? {
        guard let clip = sequence.clips.first(where: { $0.id == id }), case let .picture(.shape(shape), _, _) = clip.content,
              case let .area(area, _, _) = shape.geometry else { return nil }

        return area
    }
}

